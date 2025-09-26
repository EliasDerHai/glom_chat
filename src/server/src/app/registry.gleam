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
  Register(user_id: UserId, handle: Subject(SocketMessage))
  Unregister(user_id: UserId)
  SendMessage(user_id: UserId, message: SocketMessage)
}

type State =
  Dict(UserId, Subject(SocketMessage))

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
        |> result.map(fn(subject) { subject |> process.send(message) })

      state
    }
  }
  |> actor.continue
}
