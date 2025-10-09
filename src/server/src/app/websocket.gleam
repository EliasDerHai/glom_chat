import app/domain/chat
import app/domain/session.{type SessionEntity}
import app/domain/user.{type UserId}
import app/persist/pool.{type DbPool}
import app/registry.{
  type RegistryMessage, type SocketRegistry, OnClientRegistered,
  OnClientUnregistered,
}
import app/util/cookie
import app/util/mist_request.{type MistRequest}
import chat/shared_chat_confirmation
import gleam/bit_array
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json
import gleam/option
import gleam/otp/actor
import gleam/string
import mist.{type Next, type WebsocketConnection, type WebsocketMessage}
import socket_message/shared_client_to_server.{
  type ClientToServerSocketMessage, IsTyping, MessageConfirmation,
}
import socket_message/shared_server_to_client
import wisp
import youid/uuid

pub type WsState {
  WsState(
    user_id: UserId,
    session: SessionEntity,
    outbox: Subject(registry.ServerSideSocketOp),
  )
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
        let handle: Subject(registry.ServerSideSocketOp) = process.new_subject()
        actor.send(registry, OnClientRegistered(session.user_id, handle))

        // Store the user_id in this connection's state
        let state = WsState(session.user_id, session, handle)

        let sel =
          process.new_selector()
          |> process.select(handle)

        #(state, option.Some(sel))
      },
      on_close: fn(state) {
        // On close, send a message to unregister this user
        actor.send(registry, OnClientUnregistered(state.user_id))
        Nil
      },
      handler: fn(state, msg, conn) {
        handle_ws_message(state, msg, conn, db, registry)
      },
    )
  }
}

fn handle_ws_message(
  state: WsState,
  message: WebsocketMessage(registry.ServerSideSocketOp),
  conn: WebsocketConnection,
  db: DbPool,
  registry: SocketRegistry,
) -> Next(WsState, conn) {
  case message {
    mist.Text(text) -> {
      handle_text_messages(state, text, conn, db, registry)
      mist.continue(state)
    }
    mist.Binary(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
    mist.Custom(op) ->
      case op {
        registry.Send(message) -> {
          let body =
            message
            |> shared_server_to_client.to_json
            |> json.to_string

          let r = conn |> mist.send_text_frame(body)

          case r {
            Error(e) ->
              wisp.log_warning(
                "sending socket_message failed: " <> e |> string.inspect,
              )
            _ -> Nil
          }
          mist.continue(state)
        }

        registry.ServerInitiatedClose -> {
          wisp.log_info(
            "Server closing socket for user " <> uuid.to_string(state.user_id.v),
          )
          mist.stop()
        }
      }
  }
}

fn handle_text_messages(
  state: WsState,
  raw: String,
  conn: WebsocketConnection,
  db: DbPool,
  registry: SocketRegistry,
) -> Nil {
  case raw {
    "ping" -> mist.send_text_frame(conn, "pong") |> consume_log_error
    "echo" <> tail ->
      mist.send_text_frame(conn, "echo " <> tail |> string.trim)
      |> consume_log_error
    _ -> {
      case json.parse(raw, shared_client_to_server.decoder()) {
        Error(e) ->
          wisp.log_error(
            "could not decode client's socket message: " <> e |> string.inspect,
          )
        Ok(decoded) ->
          handle_decoded_message(state, conn, db, registry, decoded)
      }
    }
  }
}

fn handle_decoded_message(
  state: WsState,
  conn: WebsocketConnection,
  db: DbPool,
  registry: Subject(RegistryMessage),
  decoded: ClientToServerSocketMessage,
) -> Nil {
  case decoded {
    IsTyping(typer, receiver) -> {
      let assert Ok(to_be_notified) = receiver |> user.from_shared_user_id
        as { "can't notify '" <> receiver.v <> "' - not a UUID" }

      actor.send(
        registry,
        registry.OnNotifyClient(
          to_be_notified,
          shared_server_to_client.IsTyping(typer),
        ),
      )
    }

    MessageConfirmation(confirmation:) ->
      case chat.confirm_messages(db, confirmation, registry, state.session) {
        Ok(confirmation) ->
          mist.send_text_frame(
            conn,
            confirmation
              |> MessageConfirmation
              |> shared_client_to_server.to_json
              |> json.to_string,
          )
          |> consume_log_error
        e -> e |> consume_log_error
      }
  }
}

fn consume_log_error(r: Result(a, e)) -> Nil {
  case r {
    Error(error_reason) ->
      { "Error sending websocket frame: " <> error_reason |> string.inspect }
      |> io.println_error
    Ok(_) -> Nil
  }
}
