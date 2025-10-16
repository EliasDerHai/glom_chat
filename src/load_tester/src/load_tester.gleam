import bot.{type Bot, BotId}
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import http as h
import print
import shared_user.{type UserId}
import util/time
import ws

fn init(bots: Int) {
  list.range(0, bots - 1)
  |> list.map(BotId)
  |> list.map(h.signup_bot)
  |> list.map(h.login_bot)
  |> list.map(ws.connect_bot)
  |> exchange_ids
  |> list.map(fn(tuple) {
    let #(bot, ws_subject, receiver_id) = tuple
    let assert Ok(http_subject) = h.start(tuple.0)
    #(bot, ws_subject, http_subject, receiver_id)
  })
}

pub fn main() -> Nil {
  let bot_count = 15
  let interval_ms = 20
  let test_duration_ms = 10_000
  let iterations = test_duration_ms / interval_ms

  let bots = init(bot_count)

  io.println("✓ " <> bots |> list.length |> int.to_string <> " bots prepared")
  process.sleep(100)

  io.println(
    "\nStarting load test: "
    <> iterations |> int.to_string
    <> " iterations, "
    <> interval_ms |> int.to_string
    <> "ms interval, "
    <> test_duration_ms |> int.to_string
    <> "ms predictated execution\n",
  )

  let runtime = {
    let start = time.millis_now()

    list.range(1, iterations)
    |> list.each(fn(iteration) {
      bots
      |> list.each(fn(tuple) {
        let #(bot, _ws_subject, http_subject, receiver_id) = tuple
        let content =
          [
            bot.id.v,
            iteration,
            time.millis_now(),
          ]
          |> list.map(int.to_string)
          |> string.join(";")
        h.send(http_subject, receiver_id, content)
      })

      case iteration % 100 == 0 {
        True -> {
          let progress =
            int.to_float(iteration)
            /. int.to_float(iterations)
            *. 100.0
          let elapsed = time.millis_now() - start
          let rate =
            int.to_float(iteration * bot_count) /. int.to_float(elapsed) *. 1000.0

          io.println(
            "  ["
            <> int.to_string(iteration)
            <> "/"
            <> int.to_string(iterations)
            <> "] "
            <> float.to_string(progress)
            <> "% | "
            <> float.to_string(rate)
            <> " msg/s",
          )
        }
        False -> Nil
      }

      process.sleep(interval_ms)
    })

    time.millis_now() - start
  }

  io.println(
    "\nPlanned to run "
    <> test_duration_ms |> int.to_string
    <> "ms - took "
    <> runtime |> int.to_string
    <> "ms",
  )
  io.println("Waiting for responses to settle...\n")
  process.sleep(500)

  io.println("\nCollecting stats from all senders...\n")

  bots
  |> list.map(fn(tuple) { h.get_stats(tuple.2) })
  |> print.print_http_stats

  bots
  |> list.map(fn(tuple) { ws.get_stats(tuple.1) })
  |> print.print_socket_stats(iterations)
}

/// every bot gets matched with his neighbors user_id (incl. overflow)
fn exchange_ids(bots: List(#(Bot, s))) -> List(#(Bot, s, UserId)) {
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
