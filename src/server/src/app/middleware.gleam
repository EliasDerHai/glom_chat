import app/auth
import app/domain/session
import app/persist/pool.{type DbPool}
import gleam/http.{Get}
import gleam/http/request
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

  handle_request(req)
}

/// middleware that checks session_id cookie and x-csrf-token header for non-GET requests
pub fn validation_middleware(
  req: wisp.Request,
  db: DbPool,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  case session.get_session_from_cookie(req, db) {
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
              validate_csrf_and_handle(req, session_entity, handle_request)
              |> result.unwrap_both
          }
        }
      }
    }
  }
}

fn validate_csrf_and_handle(
  req: wisp.Request,
  session_entity,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> Result(wisp.Response, wisp.Response) {
  use csrf_token <- result.try(
    request.get_header(req, "x-csrf-token")
    |> result.map_error(fn(_) { wisp.response(403) }),
  )

  case auth.verify_csrf_token(session_entity, csrf_token) {
    auth.Passed -> Ok(handle_request(req))
    auth.Failed -> Error(wisp.response(403))
  }
}
