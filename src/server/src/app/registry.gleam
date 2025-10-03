import app/domain/user.{type UserId}
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/otp/actor.{type Next}
import gleam/result
import shared_socket_message.{type SocketMessage}
import youid/uuid

pub type SocketRegistry =
  Subject(RegistryMessage)

pub type RegistryMessage {
  // adds socket to 'state' - client connect
  Register(user_id: UserId, handle: Subject(ServerSideSocketOp))
  // removes socket from 'state' - for client side close
  Unregister(user_id: UserId)
  // closes the socket which in turn removes entry from 'state' - for server side close (on logout)
  ServerUnregister(user_id: UserId)
  // sends message via socket
  SendMessage(user_id: UserId, message: SocketMessage)
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
    Register(user_id, conn) -> {
      io.println("registered " <> uuid.to_string(user_id.v))
      dict.insert(state, user_id, conn)
    }
    Unregister(user_id) -> {
      io.println("unregistered " <> uuid.to_string(user_id.v))
      dict.delete(state, user_id)
    }
    SendMessage(user_id:, message:) -> {
      let _ =
        state
        |> dict.get(user_id)
        |> result.map(fn(subject) { process.send(subject, message |> Send) })

      state
    }
    ServerUnregister(user_id:) -> {
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
