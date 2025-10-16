import bot.{type Bot}
import gleam/erlang/process.{type Subject}
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import ids/encrypted_session_id
import shared_user.{type UserId}
import socket_message/shared_client_to_server
import socket_message/shared_server_to_client
import stratus.{
  type Connection, type InternalMessage, type Message, type Next, Binary, Text,
  User,
}
import util/time

pub type BotActionMsg {
  Ping
  SendToUser(to: UserId)
  GetSocketStats(reply_to: Subject(SocketStats))
}

pub fn send_ping(subject: Subject(InternalMessage(BotActionMsg))) -> Nil {
  process.send(subject, stratus.to_user_message(Ping))
}

pub fn send_message(
  subject: Subject(InternalMessage(BotActionMsg)),
  to: UserId,
) -> Nil {
  process.send(subject, stratus.to_user_message(SendToUser(to)))
}

pub fn get_stats(subject: Subject(InternalMessage(BotActionMsg))) -> SocketStats {
  let reply_subject = process.new_subject()
  process.send(subject, stratus.to_user_message(GetSocketStats(reply_subject)))
  let assert Ok(stats) = process.receive(reply_subject, 5000)

  stats
}

type SocketHandle =
  Subject(InternalMessage(BotActionMsg))

pub type SocketStats {
  SocketStats(received: Int, avg_response_ms: Float, latencies: List(Int))
}

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
      init: fn() { #(#(bot, []), None) },
      loop: fn(
        state: #(Bot, List(#(String, Int))),
        msg: Message(BotActionMsg),
        conn: Connection,
      ) -> Next(#(Bot, List(#(String, Int))), BotActionMsg) {
        case msg {
          Text(raw) -> {
            // io.println("← " <> raw)
            let next_state = #(
              state.0,
              state.1
                |> list.append([#(raw, time.millis_now())]),
            )

            stratus.continue(next_state)
          }
          Binary(_) -> stratus.continue(state)
          User(Ping) -> {
            io.println("→ sending ping")
            let _ = stratus.send_text_message(conn, "ping")
            stratus.continue(state)
          }
          User(SendToUser(to:)) -> {
            io.println("→ sending typing")
            let message =
              shared_client_to_server.IsTyping(bot.session.user_id, to)
              |> shared_client_to_server.to_json
              |> json.to_string

            let _ = stratus.send_text_message(conn, message)
            stratus.continue(state)
          }
          User(GetSocketStats(reply_to)) -> {
            process.send(reply_to, state.1 |> extract_stats_from_csvs)
            stratus.stop()
          }
        }
      },
    )

  let assert Ok(started) = stratus.initialize(builder)
  io.println(bot.id |> bot.str <> " ✓ connected")
  #(bot, started.data)
}

fn extract_stats_from_csvs(lines: List(#(String, Int))) -> SocketStats {
  let #(_, count, total_ms, latencies) =
    lines
    |> list.filter_map(fn(tuple) {
      let #(raw, utc_ms_received) = tuple

      use msg <- result.try(
        json.parse(raw, shared_server_to_client.decoder())
        |> result.map_error(fn(_) { Nil }),
      )

      use csv_string <- result.try(case msg {
        shared_server_to_client.NewMessage(message:) ->
          Ok(message.text_content |> string.join(""))
        _ -> Error(Nil)
      })

      case
        csv_string
        |> string.split(";")
        |> list.filter_map(int.parse)
      {
        [bot_id, iteration, utc_ms_sent] ->
          #(bot_id, iteration, utc_ms_sent, utc_ms_received) |> Ok
        _ -> Error(Nil)
      }
    })
    |> list.fold(#(0, 0, 0, []), fn(acc, curr) {
      let #(last_iteration, count, total_ms, latencies) = acc
      let #(bot_id, iteration, utc_ms_sent, utc_ms_received) = curr
      let latency = utc_ms_received - utc_ms_sent

      case last_iteration + 1 == iteration {
        True -> Nil
        False ->
          io.println_error(
            "msg "
            <> bot_id |> int.to_string
            <> "/"
            <> iteration |> int.to_string
            <> " out of order!",
          )
      }
      #(iteration, count + 1, total_ms + latency, [latency, ..latencies])
    })

  let avg = case count {
    0 -> 0.0
    _ -> { total_ms |> int.to_float } /. { count |> int.to_float }
  }

  SocketStats(count, avg, latencies)
}
