import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/json
import gleam/result
import gleam/string_tree
import wisp.{type Request, type Response}

pub fn users(req: Request) -> Response {
  case req.method {
    Get -> list_users()
    Post -> create_user(req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_users() -> Response {
  wisp.ok()
  |> wisp.html_body(string_tree.from_string("users!"))
}

pub type CreateUserDto {
  User(user_name: String, email: String)
}

fn decode_user() -> decode.Decoder(CreateUserDto) {
  use user_name <- decode.field("user_name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(user_name:, email:))
}

fn create_user(req: Request) -> Response {
  use json <- wisp.require_json(req)

  let result = {
    use user <- result.try(decode.run(json, decode_user()))

    let object =
      json.object([
        #("user_name", json.string(user.user_name)),
        #("email", json.string(user.email)),
      ])
    Ok(json.to_string_tree(object))
  }

  case result {
    Error(_) -> wisp.bad_request()
    Ok(json) -> wisp.json_response(json, 201)
  }
}

pub fn user(req: Request, id: String) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.html_body(string_tree.from_string("user with id " <> id))
}
