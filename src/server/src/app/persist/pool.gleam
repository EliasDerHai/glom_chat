import envoy
import gleam/erlang/process.{type Name}
import gleam/otp/actor
import gleam/otp/static_supervisor
import gleam/result
import pog

pub type DbPool {
  DbPool(name: Name(pog.Message))
}

pub fn new_supervisor_with_pool() -> #(
  actor.Started(static_supervisor.Supervisor),
  DbPool,
) {
  let name = process.new_name("pog")

  let child =
    name
    |> config
    |> pog.supervised

  let assert Ok(started) =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(child)
    |> static_supervisor.start
    as "db supervisor failed"

  #(started, DbPool(name))
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
