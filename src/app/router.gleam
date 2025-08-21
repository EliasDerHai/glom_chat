import app/route/user
import app/web
import gleam/http.{Get}
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    // This matches `/`.
    [] -> hello(req)

    // This matches `/users`.
    ["users"] -> user.users(req)

    // This matches `/users/:id`.
    // The `id` segment is bound to a variable and passed to the handler.
    ["users", id] -> user.user(req, id)

    _ -> wisp.not_found()
  }
}

fn hello(req: Request) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.string_body("hello")
}
