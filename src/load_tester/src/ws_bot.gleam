import bot_id.{type Bot, type BotActionMsg, type BotId, Bot}
import csrf_token.{type CsrfToken}
import encrypted_session_id.{type EncryptedSessionId}
import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/json
import gleam/option.{None}
import gleam/result
import shared_session.{type SessionDto}
import shared_user.{type UserId}
import socket_message/shared_client_to_server
import stratus.{type Connection, type Message}

pub fn connect_bot(
  id: BotId,
  session: SessionDto,
  csrf_token: CsrfToken,
  session_id: EncryptedSessionId,
) -> Result(Bot, String) {
  let assert Ok(req) =
    request.to("http://localhost:8000/ws")
    |> result.map(request.set_cookie(
      _,
      "session_id",
      session_id |> encrypted_session_id.v,
    ))

  // Initial state placeholder (subject will be set after initialization)
  let init_state = #(id, session_id, csrf_token, session)

  let builder =
    stratus.websocket(
      request: req,
      init: fn() { #(init_state, None) },
      loop: fn(
        state: #(BotId, EncryptedSessionId, CsrfToken, SessionDto),
        msg: Message(BotActionMsg),
        conn: Connection,
      ) -> stratus.Next(
        #(BotId, EncryptedSessionId, CsrfToken, SessionDto),
        BotActionMsg,
      ) {
        case msg {
          stratus.Text(text) -> {
            io.println("← " <> text)
            stratus.continue(state)
          }
          stratus.Binary(_) -> stratus.continue(state)
          stratus.User(bot_id.Ping) -> {
            io.println("→ sending ping")
            let _ = stratus.send_text_message(conn, "ping")
            stratus.continue(state)
          }
          stratus.User(bot_id.SendToUser(to:)) -> {
            let #(_, _, _, session) = state
            let message =
              shared_client_to_server.IsTyping(session.user_id, to)
              |> shared_client_to_server.to_json
              |> json.to_string

            let _ = stratus.send_text_message(conn, message)
            stratus.continue(state)
          }
        }
      },
    )

  stratus.initialize(builder)
  |> result.map(fn(started) {
    io.println(bot_id.str(id) <> " ✓ connected")
    Bot(id, session_id, csrf_token, session, started.data)
  })
  |> result.replace_error("Connection failed")
}

pub fn send_ping(bot: Bot) -> Nil {
  process.send(bot.subject, stratus.to_user_message(bot_id.Ping))
}

pub fn send_message(bot: Bot, to: UserId) -> Nil {
  process.send(bot.subject, stratus.to_user_message(bot_id.SendToUser(to)))
}
