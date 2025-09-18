import app/auth
import app/domain/chat
import app/domain/session
import app/domain/user
import app/environment
import app/middleware
import app/persist/pool.{type DbPool}
import app/util/cookie
import app/util/mist_request.{type MistRequest}
import gleam/bit_array
import gleam/http.{Get, Options}
import gleam/http/request
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

  // Handle CORS preflight requests
  case req.method {
    Options -> wisp.ok() |> wisp.string_body("")
    _ -> handle_routes(req, db)
  }
}

fn handle_routes(req: wisp.Request, db: DbPool) -> Response {
  case wisp.path_segments(req) {
    [] | [_] -> serve_static_file(req)
    ["api", ..sub_paths] -> handle_api_routes(req, db, sub_paths)
    _ -> wisp.not_found()
  }
}

fn handle_api_routes(
  req: wisp.Request,
  db: DbPool,
  sub_paths: List(String),
) -> Response {
  case sub_paths {
    // API endpoints - public (no validation needed)
    ["ping"] -> simple_string_response(req, "pong")
    ["users"] -> user.create_user(req, db)
    ["auth", "login"] ->
      session.login(
        req,
        db,
        auth.generate_csrf_token,
        environment.get_secret() |> bit_array.from_string,
      )
    ["auth", "me"] -> {
      let cookie_extractor = fn() {
        cookie.get_cookie_from_wisp_request(req, "session_id", wisp.Signed)
      }

      case session.get_session_from_cookie(db, cookie_extractor) {
        Ok(session) -> session.me(req, db, session)
        Error(e) -> e
      }
    }

    _ -> validate_and_handle_api_requests(req, db, sub_paths)
  }
}

// Protected API endpoints - require validation
fn validate_and_handle_api_requests(
  req: wisp.Request,
  db: DbPool,
  sub_paths: List(String),
) -> response.Response(wisp.Body) {
  use req <- middleware.validation_middleware(req, db)
  case sub_paths {
    ["auth", "logout"] -> session.logout(req, db)
    ["users", "search"] -> user.list_users(req, db)
    ["users", id] -> user.user(req, db, id)
    ["chats", id] -> chat.chats(req, db, id)

    _ -> wisp.not_found()
  }
}

fn serve_static_file(req: wisp.Request) -> Response {
  let req = case req.path {
    "/" -> request.set_path(req, "/index.html")
    _ -> req
  }

  wisp.serve_static(echo req, under: "", from: "priv/static", next: fn() {
    wisp.not_found()
  })
}

fn simple_string_response(req: wisp.Request, response: String) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.string_body(wisp.ok(), response)
}
