import bot.{type Bot, type BotActionMsg, type BotId, Bot, BotId}
import endpoints
import gleam/erlang/process
import gleam/http.{Post}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import http_sender
import ids/csrf_token.{type CsrfToken}
import ids/encrypted_session_id.{type EncryptedSessionId, EncryptedSessionId}
import shared_session.{type SessionDto}
import shared_user.{type UserId, CreateUserDto}
import socket_message/shared_client_to_server
import stratus.{type Connection, type Message, type Next, Binary, Text, User}

pub fn main() -> Nil {
  let bots =
    list.range(0, 2)
    |> list.map(BotId)
    |> list.map(signup_bot)
    |> list.map(login_bot)
    |> list.filter_map(fn(auth_result) {
      let #(id, session, csrf, encrypted_session_id) = auth_result
      connect_bot(id, session, csrf, encrypted_session_id)
    })

  io.println(
    "✓ "
    <> bots |> list.length |> int.to_string
    <> " bots connected to WebSocket",
  )
  process.sleep(100)

  bots
  |> list.each(fn(bot) { bot |> bot.send_ping })

  let bots = bots |> exchange_ids

  let actors =
    bots
    |> list.map(fn(tuple) {
      let #(bot, receiver_id) = tuple
      let assert Ok(actor) = http_sender.start(bot.csrf_token)

      actor
    })

  process.sleep(10_000)
}

pub fn signup_bot(id: BotId) -> BotId {
  let signup_json =
    CreateUserDto(id |> bot.username, id |> bot.email, bot.pw())
    |> shared_user.create_user_dto_to_json
    |> json.to_string

  let signup =
    Request(
      ..endpoints.users(),
      headers: [
        #("content-type", "application/json"),
      ],
      method: Post,
      body: signup_json,
    )

  case httpc.send(signup) {
    Ok(resp) ->
      case resp {
        Response(201, _, _) -> io.println(id |> bot.str <> " signed up")
        Response(_, _, "username-taken") ->
          io.println(id |> bot.str <> "'s signup is noop")
        e ->
          panic as {
              id |> bot.str <> "'s signup failed with: " <> e |> string.inspect
            }
      }

    Error(e) ->
      panic as {
          id |> bot.str <> "'s signup failed with: " <> e |> string.inspect
        }
  }

  id
}

pub fn login_bot(
  id: BotId,
) -> #(BotId, SessionDto, CsrfToken, EncryptedSessionId) {
  let login_json =
    shared_user.UserLoginDto(id |> bot.username |> shared_user.v, bot.pw())
    |> shared_user.user_loging_dto_to_json
    |> json.to_string

  let login =
    Request(
      ..endpoints.login(),
      headers: [
        #("content-type", "application/json"),
      ],
      method: Post,
      body: login_json,
    )

  case httpc.send(login) {
    Ok(Response(200, headers, body)) -> {
      io.println(id |> bot.str <> " logged in")

      let #(session_id, csrf_token) =
        extract_cookies_from_login_headers(headers)

      let assert Ok(session) = body |> json.parse(shared_session.decode_dto())

      #(id, session, csrf_token, session_id)
    }
    e ->
      panic as {
          id |> bot.str <> "'s login failed with: " <> e |> string.inspect
        }
  }
}

fn extract_cookies_from_login_headers(
  headers: List(#(String, String)),
) -> #(EncryptedSessionId, CsrfToken) {
  let assert [a, b] =
    headers
    |> list.filter_map(fn(h) {
      case h.0 {
        "set-cookie" -> Ok(h.1)
        _ -> Error(Nil)
      }
    })

  let kv: fn(String) -> List(#(String, String)) = fn(s: String) {
    s
    |> string.split(";")
    |> list.filter(fn(s) { s |> string.contains("=") })
    |> list.map(fn(s) {
      case { s |> string.split_once("=") } {
        Error(e) -> panic as { e |> string.inspect <> " bad header " <> s }
        Ok(v) -> v
      }
    })
  }

  let ab =
    [a, b]
    |> list.flat_map(kv)
    |> list.filter(fn(el) { el.0 == "session_id" || el.0 == "csrf_token" })

  let assert Ok(#(_, session_id)) =
    ab |> list.find(fn(el) { el.0 == "session_id" })
  let assert Ok(#(_, csrf_token)) =
    ab |> list.find(fn(el) { el.0 == "csrf_token" })

  #(session_id |> EncryptedSessionId, csrf_token |> csrf_token.CsrfToken)
}

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

  let builder =
    stratus.websocket(
      request: req,
      init: fn() { #(#(id, session_id, csrf_token, session), None) },
      loop: fn(
        state: #(BotId, EncryptedSessionId, CsrfToken, SessionDto),
        msg: Message(BotActionMsg),
        conn: Connection,
      ) -> Next(
        #(BotId, EncryptedSessionId, CsrfToken, SessionDto),
        BotActionMsg,
      ) {
        case msg {
          Text(text) -> {
            io.println("← " <> text)
            stratus.continue(state)
          }
          Binary(_) -> stratus.continue(state)
          User(bot.Ping) -> {
            io.println("→ sending ping")
            let _ = stratus.send_text_message(conn, "ping")
            stratus.continue(state)
          }
          User(bot.SendToUser(to:)) -> {
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
    io.println(bot.str(id) <> " ✓ connected")
    Bot(id, session_id, csrf_token, session, started.data)
  })
  |> result.replace_error("Connection failed")
}

/// every bot gets matched with his neighbors user_id (incl. overflow)
pub fn exchange_ids(bots: List(Bot)) -> List(#(Bot, UserId)) {
  let assert Ok(first) = bots |> list.first
  let assert Ok(last) = bots |> list.last
  bots
  |> list.window_by_2
  |> list.map(fn(tuple) {
    let #(left, right) = tuple
    #(left, right.session.user_id)
  })
  |> list.append([#(last, first.session.user_id)])
}
