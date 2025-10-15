import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import http.{type HttpStats}
import ws.{type SocketStats}

pub fn print_http_stats(http_stats: List(HttpStats)) -> Nil {
  let total_sent = http_stats |> list.fold(0, fn(acc, s) { acc + s.sent })
  let total_success = http_stats |> list.fold(0, fn(acc, s) { acc + s.success })
  let total_failed = http_stats |> list.fold(0, fn(acc, s) { acc + s.failed })

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

pub fn print_socket_stats(
  socket_stats: List(SocketStats),
  expected_iterations: Int,
) -> Nil {
  let total_received =
    socket_stats |> list.fold(0, fn(acc, s) { acc + s.received })
  let avg_response_time =
    socket_stats
    |> list.map(fn(s) { s.avg_response_ms })
    |> list.fold(0.0, fn(acc, avg) { acc +. avg })
    |> fn(total) {
      case list.length(socket_stats) {
        0 -> 0.0
        count -> total /. { count |> int.to_float }
      }
    }

  io.println("\n" <> "=" |> string.repeat(50))
  io.println("WEBSOCKET STATS")
  io.println("=" |> string.repeat(50))
  io.println("Total received:      " <> int.to_string(total_received))
  io.println(
    "Expected      :      "
    <> int.to_string(expected_iterations * { socket_stats |> list.length }),
  )
  io.println(
    "Avg response time:   " <> float.to_string(avg_response_time) <> "ms",
  )
  io.println("=" |> string.repeat(50) <> "\n")
}
