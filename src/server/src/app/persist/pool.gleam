import envoy
import gleam/erlang/process.{type Name}
import gleam/otp/static_supervisor
import gleam/result
import pog

pub type DbPool {
  DbPool(name: Name(pog.Message))
}

pub fn init() -> DbPool {
  let name = process.new_name("pog")

  let child =
    name
    |> config
    |> pog.supervised

  let assert Ok(_) =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(child)
    |> static_supervisor.start
    as "db supervisor failed"

  DbPool(name)
}

fn config(name: Name(pog.Message)) -> pog.Config {
  let assert Ok(config) = read_connection_uri(name)
    as "couldn't get DATABASE_URL from .env - make sure it's set"
  config
  |> pog.pool_size(15)
}

fn read_connection_uri(name: Name(pog.Message)) -> Result(pog.Config, Nil) {
  use database_url <- result.try(envoy.get("DATABASE_URL"))
  pog.url_config(name, database_url)
}

pub fn conn(db: DbPool) {
  pog.named_connection(db.name)
}

/// Block until the pool can serve a trivial query, or give up after
/// `attempts_left` tries (500ms apart). Used at boot to avoid serving
/// traffic before the pool has live connections - see fly.toml's
/// auto_stop_machines wake-up race.
pub fn wait_ready(db: DbPool, attempts_left: Int) -> Nil {
  case attempts_left {
    0 -> Nil
    _ ->
      case
        pog.query("select 1")
        |> pog.timeout(1500)
        |> pog.execute(conn(db))
      {
        Ok(_) -> Nil
        Error(_) -> {
          process.sleep(500)
          wait_ready(db, attempts_left - 1)
        }
      }
  }
}
