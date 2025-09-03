import app/http_router
import app/persist/migration
import app/persist/pool
import app/websocket
import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/option
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  migration.migrate_db()
  let #(_supervisor, db) = pool.new_supervisor_with_pool()

  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        // ws upgrade to WebSocket
        ["ws"] ->
          mist.websocket(
            request: req,
            on_init: fn(_conn) { #(Nil, option.None) },
            on_close: fn(_state) { io.println("bye!") },
            handler: websocket.handle_ws_message,
          )

        _ ->
          wisp_mist.handler(
            http_router.handle_request_with_db(db),
            wisp.random_string(64),
          )(req)
      }
    }
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}
