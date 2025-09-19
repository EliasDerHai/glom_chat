import gleam/dict
import gleam/erlang/process
import gleam/io
import gleam/otp/actor
import mist.{type WebsocketConnection}
import youid/uuid.{type Uuid}

pub type RegistryMessage {
  Register(user_id: Uuid, conn: WebsocketConnection)
  Unregister(user_id: Uuid)
}

/// user_id <-> WebsocketConnection
type State =
  dict.Dict(Uuid, WebsocketConnection)

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
      io.println("registered " <> uuid.to_string(user_id))
      dict.insert(state, user_id, conn)
    }
    Unregister(user_id) -> {
      io.println("unregistered " <> uuid.to_string(user_id))
      dict.delete(state, user_id)
    }
  }
  |> actor.continue
}
