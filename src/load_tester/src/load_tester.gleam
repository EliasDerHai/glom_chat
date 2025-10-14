import bot.{type Bot, type BotActionMsg, type BotId, Bot, BotId}
import endpoints
import gleam/erlang/process.{type Subject}
import gleam/float
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
import shared_session
import shared_user.{type UserId, CreateUserDto}
import socket_message/shared_client_to_server
import stratus.{
  type Connection, type InternalMessage, type Message, type Next, Binary, Text,
  User,
}

fn init(bots: Int) {
  list.range(0, bots - 1)
  |> list.map(BotId)
  |> list.map(signup_bot)
  |> list.map(login_bot)
  |> list.map(connect_bot)
  |> exchange_ids
  |> list.map(fn(tuple) {
    let #(bot, ws_subject, receiver_id) = tuple
    let assert Ok(http_subject) = http_sender.start(tuple.0)
    #(bot, ws_subject, http_subject, receiver_id)
  })
}

pub fn main() -> Nil {
  let bot_count = 5
  let interval_ms = 10
  let test_duration_ms = 10_000
  let iterations = test_duration_ms / interval_ms

  let bots = init(bot_count)

  io.println("✓ " <> bots |> list.length |> int.to_string <> " bots prepared")
  process.sleep(100)

  io.println(
    "\nStarting load test: 100 "
    <> iterations |> int.to_string
    <> "iterations, "
    <> interval_ms |> int.to_string
    <> "ms interval, "
    <> test_duration_ms |> int.to_string
    <> "s total\n",
  )

  list.range(1, iterations)
  |> list.each(fn(iteration) {
    bots
    |> list.each(fn(tuple) {
      let #(bot, _ws_subject, http_subject, receiver_id) = tuple
      let content =
        "msg-" <> bot.id |> bot.str <> "-" <> iteration |> int.to_string
      http_sender.send(http_subject, receiver_id, content)
    })

    process.sleep(interval_ms)
  })

  io.println("\nWaiting for responses to settle...\n")
  process.sleep(500)

  io.println("\nCollecting stats from all senders...\n")

  let all_stats =
    bots
    |> list.map(fn(tuple) { http_sender.get_stats(tuple.2) })

  let total_sent = all_stats |> list.fold(0, fn(acc, s) { acc + s.sent })
  let total_success = all_stats |> list.fold(0, fn(acc, s) { acc + s.success })
  let total_failed = all_stats |> list.fold(0, fn(acc, s) { acc + s.failed })

  io.println("\n" <> "=" |> string.repeat(50))
  io.println("AGGREGATE STATS")
  io.println("=" |> string.repeat(50))
  io.println("Total sent:    " <> int.to_string(total_sent))
  io.println("Total success: " <> int.to_string(total_success))
  io.println("Total failed:  " <> int.to_string(total_failed))
  io.println(
    "Success rate:  "
    <> {
      case total_sent {
        0 -> "0.0"
        _ -> {
          let rate =
            int.to_float(total_success) /. int.to_float(total_sent) *. 100.0
          float.to_string(rate)
        }
      }
    }
    <> "%",
  )
  io.println("=" |> string.repeat(50) <> "\n")
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

pub fn login_bot(id: BotId) -> Bot {
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

      Bot(id, session_id, csrf_token, session)
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

type SocketHandle =
  Subject(InternalMessage(BotActionMsg))

pub fn connect_bot(bot: Bot) -> #(Bot, SocketHandle) {
  let assert Ok(req) =
    request.to("http://localhost:8000/ws")
    |> result.map(request.set_cookie(
      _,
      "session_id",
      bot.session_id |> encrypted_session_id.v,
    ))

  let builder =
    stratus.websocket(
      request: req,
      init: fn() { #(bot, None) },
      loop: fn(state: Bot, msg: Message(BotActionMsg), conn: Connection) -> Next(
        Bot,
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
              shared_client_to_server.IsTyping(bot.session.user_id, to)
              |> shared_client_to_server.to_json
              |> json.to_string

            let _ = stratus.send_text_message(conn, message)
            stratus.continue(state)
          }
        }
      },
    )

  let assert Ok(started) = stratus.initialize(builder)

  io.println(bot.id |> bot.str <> " ✓ connected")

  #(bot, started.data)
}

/// every bot gets matched with his neighbors user_id (incl. overflow)
pub fn exchange_ids(bots: List(#(Bot, s))) -> List(#(Bot, s, UserId)) {
  let assert Ok(first) = bots |> list.first
  let assert Ok(last) = bots |> list.last
  bots
  |> list.window_by_2
  |> list.map(fn(tuple) {
    let #(left, right) = tuple
    #(left.0, left.1, { right.0 }.session.user_id)
  })
  |> list.append([#(last.0, last.1, { first.0 }.session.user_id)])
}
