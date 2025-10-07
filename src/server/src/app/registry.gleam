import app/domain/user.{type UserId}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor.{type Next}
import gleam/result
import gleam/set
import socket_message/shared_server_to_client.{
  type ServerToClientSocketMessage, OnlineHasChanged,
}
import youid/uuid

pub type SocketRegistry =
  Subject(RegistryMessage)

pub type RegistryMessage {
  // adds socket to 'state' - client connect
  OnClientRegistered(user_id: UserId, handle: Subject(ServerSideSocketOp))
  // removes socket from 'state' - for client side close
  OnClientUnregistered(user_id: UserId)
  // closes the socket which in turn removes entry from 'state' - for server side close (on logout)
  OnServerUnregisteredClient(user_id: UserId)
  // sends message via socket to client
  OnNotifyClient(user_id: UserId, message: ServerToClientSocketMessage)
}

pub type ServerSideSocketOp {
  Send(ServerToClientSocketMessage)
  ServerInitiatedClose
}

type State =
  Dict(UserId, Subject(ServerSideSocketOp))

pub fn init() -> SocketRegistry {
  let assert Ok(started) =
    actor.new(dict.new())
    |> actor.on_message(handle_message)
    |> actor.start
  started.data
}

fn handle_message(
  state: State,
  message: RegistryMessage,
) -> Next(State, RegistryMessage) {
  case message {
    OnClientRegistered(user_id, conn) -> {
      io.println("registered " <> uuid.to_string(user_id.v))

      state
      |> dict.insert(user_id, conn)
      |> publish_online_changed(state)
    }
    OnClientUnregistered(user_id) -> {
      io.println("unregistered " <> uuid.to_string(user_id.v))

      state
      |> dict.delete(user_id)
      |> publish_online_changed(state)
    }
    OnNotifyClient(user_id:, message:) -> {
      let _ =
        state
        |> dict.get(user_id)
        |> result.map(fn(subject) { process.send(subject, message |> Send) })

      state
    }
    OnServerUnregisteredClient(user_id:) -> {
      let _ =
        state
        |> dict.get(user_id)
        |> result.map(fn(subject) {
          process.send(subject, ServerInitiatedClose)
        })

      state
    }
  }
  |> actor.continue
}

// side effect of sending out the online list (returns unchanged state)
fn publish_online_changed(new_state: State, old_state: State) -> State {
  // early return if no real change 
  // eg. browser refresh on client
  let new_online = new_state |> dict.keys |> set.from_list
  let old_online = old_state |> dict.keys |> set.from_list
  use <- bool.guard(when: new_online == old_online, return: new_state)

  let message =
    new_state
    |> dict.keys
    |> list.map(user.to_shared_user_id)
    |> OnlineHasChanged
    |> Send

  new_state
  |> dict.values
  |> list.each(fn(subject) { process.send(subject, message) })

  new_state
}
