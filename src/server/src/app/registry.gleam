import app/domain/user.{type UserId}
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor.{type Next}
import gleam/result
import shared_socket_message.{type SocketMessage, OnlineHasChanged}
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
  OnNotifyClient(user_id: UserId, message: SocketMessage)
}

pub type ServerSideSocketOp {
  Send(SocketMessage)
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
      |> publish_online_changed
    }
    OnClientUnregistered(user_id) -> {
      io.println("unregistered " <> uuid.to_string(user_id.v))

      state
      |> dict.delete(user_id)
      |> publish_online_changed
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
fn publish_online_changed(state: State) -> State {
  let message =
    state
    |> dict.keys
    |> list.map(user.to_shared_user_id)
    |> OnlineHasChanged
    |> Send

  state
  |> dict.values
  |> list.each(fn(subject) { process.send(subject, message) })

  state
}
