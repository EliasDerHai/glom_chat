import app/domain/session
import app/domain/user.{type UserId}
import app/persist/pool.{type DbPool}
import app/registry.{type SocketRegistry, Register, Unregister}
import app/util/cookie
import app/util/mist_request.{type MistRequest}
import gleam/bit_array
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/option
import gleam/otp/actor
import gleam/string
import mist.{type Next, type WebsocketConnection, type WebsocketMessage}
import shared_socket_message.{type SocketMessage}
import wisp

pub type WsState {
  WsState(user_id: UserId, outbox: Subject(SocketMessage))
}

pub fn handle_ws_request(
  db: DbPool,
  registry: SocketRegistry,
  secret_key: String,
) {
  fn(mist_req: MistRequest) {
    mist.websocket(
      request: mist_req,
      on_init: fn(_) {
        let cookie_extractor = fn() {
          cookie.get_cookie_from_mist_request(
            mist_req,
            "session_id",
            wisp.Signed,
            bit_array.from_string(secret_key),
          )
        }

        let assert Ok(session) =
          session.get_session_from_cookie(db, cookie_extractor)
          as "could not extract session from ws-handshake"

        // Allow sending out messages 
        let handle: Subject(SocketMessage) = process.new_subject()
        actor.send(registry, Register(session.user_id, handle))

        // Store the user_id in this connection's state
        let state = WsState(session.user_id, handle)

        let sel =
          process.new_selector()
          |> process.select(handle)

        #(state, option.Some(sel))
      },
      on_close: fn(state) {
        // On close, send a message to unregister this user
        actor.send(registry, Unregister(state.user_id))
        Nil
      },
      handler: fn(state, msg, conn) { handle_ws_message(state, msg, conn, db) },
    )
  }
}

fn handle_ws_message(
  state: WsState,
  message: WebsocketMessage(SocketMessage),
  conn: WebsocketConnection,
  db: DbPool,
) -> Next(WsState, conn) {
  case message {
    mist.Text(text) -> {
      handle_text_messages(text, conn, db)
      mist.continue(state)
    }
    mist.Binary(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
    mist.Custom(message) -> {
      let body =
        message
        |> shared_socket_message.socket_message_to_json
        |> json.to_string

      let r = conn |> mist.send_text_frame(body)

      case r {
        Error(e) ->
          io.print_error(
            "sending socket_message failed: " <> e |> string.inspect,
          )
        _ -> Nil
      }
      mist.continue(state)
    }
  }
}

fn handle_text_messages(
  raw: String,
  conn: WebsocketConnection,
  _db: DbPool,
) -> Nil {
  let r = case raw {
    "ping" -> mist.send_text_frame(conn, "pong")
    _ -> mist.send_text_frame(conn, "echo: " <> raw)
  }

  case r {
    Error(error_reason) ->
      { "Error sending websocket frame: " <> error_reason |> string.inspect }
      |> io.println_error
    Ok(Nil) -> Nil
  }
}
