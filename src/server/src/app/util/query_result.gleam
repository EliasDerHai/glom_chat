import gleam/result
import gleam/string
import pog.{type QueryError, type Returned}
import wisp.{type Response}

pub fn map_query_result(r: Result(ok, QueryError)) -> Result(ok, Response) {
  r |> result.map_error(map_err)
}

fn map_err(query_error: QueryError) {
  wisp.log_info("query_error: " <> query_error |> string.inspect)
  wisp.internal_server_error()
  |> wisp.string_body("db-query failed")
}

pub fn map_query_result_expect_single_row(
  r: Result(Returned(a), QueryError),
) -> Result(Returned(a), Response) {
  r
  |> map_query_result
  |> result.map(fn(ok) {
    case ok.count {
      1 -> Ok(ok)
      _ -> {
        wisp.log_info("query_error: expected exactly one row")
        Error(
          wisp.not_found()
          |> wisp.string_body(
            "db-query failed - expected exactly one row (affected or selected)",
          ),
        )
      }
    }
  })
  |> result.flatten
}
