import app/environment
import app/http_router
import app/persist/migration
import app/persist/pool
import app/websocket
import gleam/erlang/process
import gleam/http/request
import mist
import wisp

pub fn main() {
  wisp.configure_logger()

  // load .env
  environment.load_dot_env()
  let secret_key = environment.get_secret()

  // db migration and pool setup
  migration.migrate_db()
  let #(_supervisor, db) = pool.new_supervisor_with_pool()

  let assert Ok(_) =
    fn(req) {
      case request.path_segments(req) {
        ["ws"] -> websocket.handle_ws_request(db)(req)
        _ -> http_router.handle_http_request(db, secret_key)(req)
      }
    }
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  // The web server runs in new Erlang process, so put this one to sleep while
  // it works concurrently.
  process.sleep_forever()
}
