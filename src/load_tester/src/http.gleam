import bot.{type Bot, type BotId, Bot}
import chat/shared_chat_creation_dto.{ChatMessageCreationDto}
import endpoints
import gleam/erlang/process.{type Subject}
import gleam/http.{Post}
import gleam/http/request.{Request}
import gleam/http/response.{type Response, Response}
import gleam/httpc.{type HttpError}
import gleam/io
import gleam/json
import gleam/list
import gleam/otp/actor.{type Next, type StartError}
import gleam/result
import gleam/string
import ids/csrf_token.{type CsrfToken}
import ids/encrypted_session_id.{type EncryptedSessionId, EncryptedSessionId}
import shared_session
import shared_user.{type UserId, CreateUserDto}

pub type HttpSenderMsg {
  SendMessage(to: UserId, content: String, reply_to: Subject(HttpSenderMsg))
  HttpResult(Result(Response(String), HttpError))
  GetHttpStats(reply_to: Subject(HttpStats))
}

pub type HttpStats {
  Stats(sent: Int, success: Int, failed: Int)
}

type State {
  State(bot: Bot, sent: Int, success: Int, failed: Int)
}

pub fn start(bot: Bot) -> Result(Subject(HttpSenderMsg), StartError) {
  actor.new(State(bot:, sent: 0, success: 0, failed: 0))
  |> actor.on_message(handle_message)
  |> actor.start
  |> result.map(fn(started) { started.data })
}

fn handle_message(
  state: State,
  msg: HttpSenderMsg,
) -> Next(State, HttpSenderMsg) {
  case msg {
    SendMessage(to, content, reply_to) -> {
      let _pid =
        process.spawn_unlinked(fn() {
          let result =
            send_http_message(
              to,
              content,
              state.bot.csrf_token,
              state.bot.session_id,
            )
          process.send(reply_to, HttpResult(result))
        })

      //    io.println(
      //      "→ HTTP request spawned (total sent: "
      //      <> int.to_string(state.sent + 1)
      //      <> ")",
      //    )
      actor.continue(State(..state, sent: state.sent + 1))
    }

    HttpResult(Ok(_response)) -> {
      //     io.println(
      //       "← HTTP "
      //       <> int.to_string(response.status)
      //       <> " (success: "
      //       <> int.to_string(state.success + 1)
      //       <> ")",
      //     )
      actor.continue(State(..state, success: state.success + 1))
    }

    HttpResult(Error(_err)) -> {
      //     io.println(
      //       "← HTTP Error: "
      //       <> string.inspect(err)
      //       <> " (failed: "
      //       <> int.to_string(state.failed + 1)
      //       <> ")",
      //     )
      actor.continue(State(..state, failed: state.failed + 1))
    }

    GetHttpStats(reply_to) -> {
      process.send(reply_to, Stats(state.sent, state.success, state.failed))
      actor.continue(state)
    }
  }
}

fn send_http_message(
  to: UserId,
  content: String,
  csrf: CsrfToken,
  encrypted_session_id: EncryptedSessionId,
) -> Result(Response(String), HttpError) {
  Request(
    ..endpoints.chats(),
    headers: [
      #("content-type", "application/json"),
      #("x-csrf-token", csrf.v),
    ],
    method: Post,
    body: ChatMessageCreationDto(to, [content])
      |> shared_chat_creation_dto.to_json
      |> json.to_string,
  )
  |> request.set_cookie("session_id", encrypted_session_id.v)
  |> request.set_cookie("csrf_token", csrf.v)
  |> httpc.send
}

pub fn send(sender: Subject(HttpSenderMsg), to: UserId, content: String) -> Nil {
  process.send(sender, SendMessage(to, content, sender))
}

pub fn get_stats(sender: Subject(HttpSenderMsg)) -> HttpStats {
  process.call(sender, 5000, GetHttpStats)
}

// other requests

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
