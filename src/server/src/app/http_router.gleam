import app/auth
import app/domain/session
import app/domain/user
import app/middleware
import app/persist/pool.{type DbPool}
import gleam/http.{Get, Post}
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn handle_http_request(db: DbPool, secret_key: String) {
  wisp_mist.handler(
    fn(req: wisp.Request) { handle_request(req, db) },
    secret_key,
  )
}

fn handle_request(req: Request, db: DbPool) -> Response {
  use req <- middleware.default_middleware(req)

  case wisp.path_segments(req) {
    // Public endpoints - no validation needed
    [] -> simple_string_response(req, "hello")
    ["ping"] -> simple_string_response(req, "pong")
    ["auth", "login"] -> session.login(req, db, auth.generate_csrf_token)
    ["users"] ->
      case req.method {
        // Signup - no validation
        Post -> user.create_user(req, db)
        Get -> {
          use _ <- middleware.validation_middleware(req, db)
          user.list_users(db)
        }
        _ -> wisp.method_not_allowed([Get, Post])
      }

    _ -> validate_and_handle_requests(req, db)
  }
}

// Protected endpoints - require validation
fn validate_and_handle_requests(req, db) {
  use req <- middleware.validation_middleware(req, db)
  case wisp.path_segments(req) {
    ["auth", "logout"] -> session.logout(req, db)
    ["auth", "me"] -> session.me(req, db)
    ["users", id] -> user.user(req, db, id)

    _ -> wisp.not_found()
  }
}

fn simple_string_response(req: Request, response: String) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.string_body(wisp.ok(), response)
}
