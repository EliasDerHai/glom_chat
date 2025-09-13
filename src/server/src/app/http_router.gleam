import app/auth
import app/domain/session
import app/domain/user
import app/middleware
import app/persist/pool.{type DbPool}
import app/util/cookie
import app/util/mist_request.{type MistRequest}
import gleam/http.{Get}
import gleam/http/response
import mist
import wisp.{type Response}
import wisp/wisp_mist

pub fn handle_http_request(
  db: DbPool,
  secret_key: String,
) -> fn(MistRequest) -> response.Response(mist.ResponseData) {
  wisp_mist.handler(
    fn(req: wisp.Request) { handle_request(req, db) },
    secret_key,
  )
}

fn handle_request(req: wisp.Request, db: DbPool) -> Response {
  use req <- middleware.default_middleware(req)

  case wisp.path_segments(req) {
    // Public endpoints - no validation needed
    [] -> simple_string_response(req, "hello")
    ["ping"] -> simple_string_response(req, "pong")
    ["users"] -> user.create_user(req, db)
    ["auth", "login"] -> session.login(req, db, auth.generate_csrf_token)
    ["auth", "me"] -> {
      case cookie.get_session_from_wisp_req(req, db) {
        Ok(session) -> session.me(req, db, session)
        Error(e) -> e
      }
    }

    _ -> validate_and_handle_requests(req, db)
  }
}

// Protected endpoints - require validation
fn validate_and_handle_requests(req, db) {
  use req <- middleware.validation_middleware(req, db)
  case wisp.path_segments(req) {
    ["auth", "logout"] -> session.logout(req, db)
    ["users", "search"] -> user.list_users(req, db)
    ["users", id] -> user.user(req, db, id)

    _ -> wisp.not_found()
  }
}

fn simple_string_response(req: wisp.Request, response: String) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.string_body(wisp.ok(), response)
}
