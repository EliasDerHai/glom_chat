import app/domain/user.{type UserId}
import gleam/dict
import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import mist.{type WebsocketConnection}
import youid/uuid

pub type RegistryMessage {
  Register(user_id: UserId, conn: WebsocketConnection)
  Unregister(user_id: UserId)
}

type State =
  dict.Dict(UserId, WebsocketConnection)

pub fn init() -> process.Subject(RegistryMessage) {
  let assert Ok(started) =
    actor.new(dict.new())
    |> actor.on_message(handle_message)
    |> actor.start
  started.data
}

fn handle_message(
  state: State,
  message: RegistryMessage,
) -> actor.Next(State, RegistryMessage) {
  case message {
    Register(user_id, conn) -> {
      io.println("registered " <> uuid.to_string(user_id.v))
      dict.insert(state, user_id, conn)
    }
    Unregister(user_id) -> {
      io.println("unregistered " <> uuid.to_string(user_id.v))
      dict.delete(state, user_id)
    }
  }
  |> actor.continue
}
