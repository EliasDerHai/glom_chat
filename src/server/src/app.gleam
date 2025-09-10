import app/environment
import app/http_router
import app/persist/migration
import app/persist/pool
import app/registry
import app/util/mist_request.{type MistRequest}
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
  let db = pool.init()
  let socket_registry = registry.init()

  let assert Ok(_) =
    fn(req: MistRequest) {
      case request.path_segments(req) {
        ["ws"] ->
          websocket.handle_ws_request(db, socket_registry, secret_key)(req)
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
