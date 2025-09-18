import app/domain/session
import app/environment
import app/persist/pool.{type DbPool}
import app/util/cookie
import gleam/http.{Get}
import gleam/http/request
import gleam/http/response
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
  handle_request: fn(wisp.Request) -> wisp.Response,
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
            Get -> handle_request(req)
            _ ->
              validate_csrf_and_handle(req, handle_request)
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
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> Result(wisp.Response, wisp.Response) {
  use csrf_token_cookie <- result.try(
    cookie.get_cookie_from_wisp_request(req, "csrf_token", wisp.PlainText)
    |> result.map_error(fn(_) {
      echo "no csrf cookie"
      wisp.response(403)
    }),
  )

  use csrf_token_header <- result.try(
    request.get_header(req, "x-csrf-token")
    |> result.map_error(fn(_) {
      echo "no x-csrf header"
      wisp.response(403)
    }),
  )

  case csrf_token_cookie.v == csrf_token_header {
    False -> Error(wisp.response(403))
    True -> Ok(handle_request(req))
  }
}

pub fn cors_middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let response = handle_request(req)
  let client_origin = environment.get_client_origin()

  response
  |> response.set_header("access-control-allow-origin", client_origin)
  |> response.set_header("access-control-allow-credentials", "true")
  |> response.set_header(
    "access-control-allow-methods",
    "GET, POST, PUT, DELETE, OPTIONS",
  )
  |> response.set_header(
    "access-control-allow-headers",
    "content-type, x-csrf-token",
  )
}
