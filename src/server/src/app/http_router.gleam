import app/domain/session
import app/domain/user
import app/persist/pool.{type DbPool}
import gleam/http.{Get}
import wisp.{type Request, type Response}

pub fn handle_request_with_db(db: DbPool) -> fn(Request) -> Response {
  fn(req) { handle_request(req, db) }
}

fn handle_request(req: Request, db: DbPool) -> Response {
  use req <- middleware(req)

  case wisp.path_segments(req) {
    // `/`
    [] -> simple_string_response(req, "hello")
    // `/ping`
    ["ping"] -> simple_string_response(req, "pong")

    // `/auth/login`
    ["auth", "login"] -> session.login(req, db)
    // `/auth/logout`
    ["auth", "logout"] -> session.logout(req, db)
    // `/auth/me`
    ["auth", "me"] -> session.me(req, db)

    // `/users/:id`
    ["users", id] -> user.user(req, db, id)
    // `/users`
    ["users"] -> user.users(req, db)

    _ -> wisp.not_found()
  }
}

fn middleware(
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

fn simple_string_response(req: Request, response: String) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.string_body(wisp.ok(), response)
}
