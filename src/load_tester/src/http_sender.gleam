import bot.{type Bot}
import chat/shared_chat_creation_dto.{ChatMessageCreationDto}
import endpoints
import gleam/erlang/process.{type Subject}
import gleam/http.{Post}
import gleam/http/request.{Request}
import gleam/http/response.{type Response}
import gleam/httpc.{type HttpError}
import gleam/int
import gleam/io
import gleam/json
import gleam/otp/actor.{type Next, type StartError}
import gleam/result
import gleam/string
import ids/csrf_token.{type CsrfToken}
import ids/encrypted_session_id.{type EncryptedSessionId}
import shared_user.{type UserId}

pub type HttpSenderMsg {
  SendMessage(to: UserId, content: String, reply_to: Subject(HttpSenderMsg))
  HttpResult(Result(Response(String), HttpError))
  GetStats(reply_to: Subject(Stats))
}

pub type Stats {
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

      io.println(
        "→ HTTP request spawned (total sent: "
        <> int.to_string(state.sent + 1)
        <> ")",
      )
      actor.continue(State(..state, sent: state.sent + 1))
    }

    HttpResult(Ok(response)) -> {
      io.println(
        "← HTTP "
        <> int.to_string(response.status)
        <> " (success: "
        <> int.to_string(state.success + 1)
        <> ")",
      )
      actor.continue(State(..state, success: state.success + 1))
    }

    HttpResult(Error(err)) -> {
      io.println(
        "← HTTP Error: "
        <> string.inspect(err)
        <> " (failed: "
        <> int.to_string(state.failed + 1)
        <> ")",
      )
      actor.continue(State(..state, failed: state.failed + 1))
    }

    GetStats(reply_to) -> {
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

pub fn get_stats(sender: Subject(HttpSenderMsg)) -> Stats {
  process.call(sender, 5000, GetStats)
}
