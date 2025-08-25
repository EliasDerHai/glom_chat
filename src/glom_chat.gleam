import app/persist/pool
import app/router
import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/option
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  // TODO: why do we need this?
  let secret_key_base = wisp.random_string(64)

  // database connection pool supervisor
  let #(_supervisor, db) = pool.new_supervisor_with_pool()

  let handler = router.handle_request_with_db(db)

  let assert Ok(_) =
    fn(req) {
      echo req
      case request.path_segments(req) {
        // /ws upgrade to WebSocket
        ["ws"] ->
          mist.websocket(
            request: req,
            on_init: fn(_conn) { #(Nil, option.None) },
            on_close: fn(_state) { io.println("bye!") },
            handler: handle_ws_message,
          )

        _ -> wisp_mist.handler(handler, secret_key_base)(req)
      }
    }
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}

/// echo/ping example
fn handle_ws_message(state, msg, conn) {
  case msg {
    mist.Text("ping") -> {
      let _ = mist.send_text_frame(conn, "pong")
      mist.continue(state)
    }
    mist.Text(text) -> {
      let _ = mist.send_text_frame(conn, "echo: " <> text)
      mist.continue(state)
    }
    mist.Binary(_) | mist.Custom(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}
