import app/domain/session
import app/persist/pool.{type DbPool}
import app/util/cookie
import gleam/http.{Get}
import gleam/http/request
import gleam/io
import gleam/order
import gleam/result
import gleam/time/timestamp
import wisp

pub fn default_middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  // Permit browsers to simulate methods other than GET and POST using the
  // `_method` query parameter.
  let req = wisp.method_override(req)

  // Log information about the request and response.
  use <- wisp.log_request(req)

  // Return a default 500 response if the request handler crashes.
  use <- wisp.rescue_crashes

  // Rewrite HEAD requests to GET requests and return an empty body.
  use req <- wisp.handle_head(req)

  // Add CORS headers
  // TODO: remove ? use req <- cors_middleware(req)

  handle_request(req)
}

/// middleware that checks session_id cookie and x-csrf-token header for non-GET requests
pub fn validation_middleware(
  req: wisp.Request,
  // TODO: do we really need to do a select for each req?? isn't dual verification enough? -> reconsider
  db: DbPool,
  handle_request: fn(wisp.Request, session.SessionEntity) -> wisp.Response,
) -> wisp.Response {
  let cookie_extractor = fn() {
    cookie.get_cookie_from_wisp_request(req, "session_id", wisp.Signed)
  }

  case session.get_session_from_cookie(db, cookie_extractor) {
    Error(response) -> response
    Ok(session_entity) -> {
      case
        timestamp.compare(session_entity.expires_at, timestamp.system_time())
      {
        order.Lt -> wisp.response(401)
        order.Gt | order.Eq -> {
          case req.method {
            Get -> handle_request(req, session_entity)
            _ ->
              validate_csrf_and_handle(req, session_entity, handle_request)
              |> result.unwrap_both
          }
        }
      }
    }
  }
}

// https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html#token-based-mitigation
fn validate_csrf_and_handle(
  req: wisp.Request,
  session: session.SessionEntity,
  handle_request: fn(wisp.Request, session.SessionEntity) -> wisp.Response,
) -> Result(wisp.Response, wisp.Response) {
  use csrf_token_cookie <- result.try(
    cookie.get_cookie_from_wisp_request(req, "csrf_token", wisp.PlainText)
    |> result.map_error(fn(_) {
      io.println("no csrf cookie")
      wisp.response(403)
    }),
  )

  use csrf_token_header <- result.try(
    request.get_header(req, "x-csrf-token")
    |> result.map_error(fn(_) {
      io.println("no x-csrf header")
      wisp.response(403)
    }),
  )

  case csrf_token_cookie.v == csrf_token_header {
    False -> {
      io.print_error(
        "csrf token an x-csrf header don't match"
        <> "\ncookie: "
        <> csrf_token_cookie.v
        <> "\nheader: "
        <> csrf_token_header,
      )
      Error(wisp.response(403))
    }
    True -> Ok(handle_request(req, session))
  }
}
