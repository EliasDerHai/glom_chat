import app/domain/session.{type SessionEntity}
import app/persist/pool.{type DbPool}
import app/util/mist_request.{type MistRequest}
import gleam/bit_array
import gleam/crypto
import gleam/http
import gleam/http/cookie
import gleam/io
import gleam/list
import gleam/result
import wisp.{type Response}
import youid/uuid

// TODO: 
// remove workaround once websockets are implemented in wisp
// see: https://github.com/gleam-wisp/wisp/issues/10
pub fn get_session_from_mist_req(
  req: MistRequest,
  db: DbPool,
  secret: BitArray,
) -> Result(SessionEntity, Response) {
  use session_id_str <- result.try(
    get_cookie_from_header(req.headers, "session_id", wisp.Signed, secret)
    |> result.map_error(fn(_) {
      io.println("Failed to get session_id cookie")
      wisp.response(401)
    }),
  )

  use session_id <- result.try(
    uuid.from_string(session_id_str)
    |> result.map_error(fn(_) {
      io.println("Failed to parse session_id UUID")
      wisp.response(401)
    }),
  )

  use session <- result.try(
    session.get_session(db, session_id)
    |> result.map_error(fn(_) {
      io.println("Failed to get session from database")
      wisp.response(401)
    }),
  )

  Ok(session)
}

fn get_cookie_from_header(
  headers: List(http.Header),
  cookie_name: String,
  security: wisp.Security,
  secret: BitArray,
) -> Result(String, Nil) {
  use value <- result.try(
    headers
    |> list.filter_map(fn(header) {
      let #(name, value) = header
      case name {
        "cookie" -> Ok(cookie.parse(value))
        _ -> Error(Nil)
      }
    })
    |> list.flatten()
    |> list.key_find(cookie_name),
  )

  use value <- result.try(case security {
    wisp.PlainText -> bit_array.base64_decode(value)
    wisp.Signed -> crypto.verify_signed_message(value, secret)
  })

  value |> bit_array.to_string
}

pub fn get_session_from_wisp_req(
  req: wisp.Request,
  db: DbPool,
) -> Result(SessionEntity, Response) {
  use session_id_str <- result.try(
    wisp.get_cookie(req, "session_id", wisp.Signed)
    |> result.map_error(fn(_) {
      io.println("Failed to get session_id cookie")
      wisp.response(401)
    }),
  )

  use session_id <- result.try(
    uuid.from_string(session_id_str)
    |> result.map_error(fn(_) {
      io.println("Failed to parse session_id UUID")
      wisp.response(401)
    }),
  )

  use session <- result.try(
    session.get_session(db, session_id)
    |> result.map_error(fn(_) {
      io.println("Failed to get session from database")
      wisp.response(401)
    }),
  )

  Ok(session)
}
