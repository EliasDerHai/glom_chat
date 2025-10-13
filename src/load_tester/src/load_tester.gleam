import bot_id.{type BotId, BotId}
import csrf_token.{type CsrfToken}
import encrypted_session_id.{type EncryptedSessionId, EncryptedSessionId}
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
import gleam/string
import shared_session.{type SessionDto}
import shared_user.{CreateUserDto}
import ws_bot

pub fn main() -> Nil {
  let connected_bots =
    list.range(0, 1)
    |> list.map(BotId)
    |> list.map(signup_bot)
    |> list.map(login_bot)
    |> list.filter_map(fn(auth_result) {
      let #(id, session, csrf, encrypted_session_id) = auth_result
      ws_bot.connect_bot(id, session, csrf, encrypted_session_id)
    })

  io.println(
    "✓ "
    <> connected_bots |> list.length |> int.to_string
    <> " bots connected to WebSocket",
  )
  process.sleep(100)

  connected_bots
  |> list.each(fn(bot) { bot |> ws_bot.send_ping })

  process.sleep(100)
  // process.sleep_forever()
}

pub fn signup_bot(id: BotId) -> BotId {
  let signup_json =
    CreateUserDto(id |> bot_id.username, id |> bot_id.email, bot_id.pw())
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
        Response(201, _, _) -> io.println(id |> bot_id.str <> " signed up")
        Response(_, _, "username-taken") ->
          io.println(id |> bot_id.str <> "'s signup is noop")
        e ->
          panic as {
              id |> bot_id.str
              <> "'s signup failed with: "
              <> e |> string.inspect
            }
      }

    Error(e) ->
      panic as {
          id |> bot_id.str <> "'s signup failed with: " <> e |> string.inspect
        }
  }

  id
}

pub fn login_bot(
  id: BotId,
) -> #(BotId, SessionDto, CsrfToken, EncryptedSessionId) {
  let login_json =
    shared_user.UserLoginDto(
      id |> bot_id.username |> shared_user.v,
      bot_id.pw(),
    )
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
      io.println(id |> bot_id.str <> " logged in")

      let #(session_id, csrf_token) =
        extract_cookies_from_login_headers(headers)

      let assert Ok(session) = body |> json.parse(shared_session.decode_dto())

      #(id, session, csrf_token, session_id)
    }
    e ->
      panic as {
          id |> bot_id.str <> "'s login failed with: " <> e |> string.inspect
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
