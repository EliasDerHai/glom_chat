import gleam/result
import pog.{type QueryError}
import wisp.{type Response}

pub fn map_query_result(r: Result(ok, QueryError)) -> Result(ok, Response) {
  r |> result.map_error(map_err)
}

fn map_err(query_error: QueryError) {
  echo query_error
  wisp.internal_server_error()
  |> wisp.string_body("db-query failed")
}
