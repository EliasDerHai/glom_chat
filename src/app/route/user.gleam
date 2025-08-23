import app/persist/setup.{type DbPool}
import app/persist/sql
import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/json
import gleam/result
import gleam/string_tree
import pog
import wisp.{type Request, type Response}
import youid/uuid

pub fn users(req: Request, db: DbPool) -> Response {
  case req.method {
    Get -> list_users(db)
    Post -> create_user(req, db)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_users(db: DbPool) -> Response {
  wisp.ok()
  |> wisp.html_body(string_tree.from_string("users!"))
}

/// {
///   "user_name": "John",
///   "email": "john.boy@gleam.com"
/// }
pub type CreateUserDto {
  User(user_name: String, email: String)
}

fn decode_user() -> decode.Decoder(CreateUserDto) {
  use user_name <- decode.field("user_name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(user_name:, email:))
}

fn create_user(req: Request, db: DbPool) -> Response {
  use json <- wisp.require_json(req)

  let result = {
    let user_id = uuid.v7()
    let conn = pog.named_connection(db.name)

    use dto <- result.try(
      decode_user() |> decode.run(json, _) |> result.map_error(fn(_) { Nil }),
    )

    use _ <- result.try(
      conn
      |> sql.insert_user(user_id, dto.user_name, dto.email, False)
      |> result.map_error(fn(_) { Nil }),
    )

    let object =
      json.object([
        #("id", uuid.to_string(user_id) |> json.string()),
        #("user_name", json.string(dto.user_name)),
        #("email", json.string(dto.email)),
        #("email_verified", json.string("false")),
      ])
    Ok(json.to_string_tree(object))
  }

  case result {
    Error(_) -> wisp.bad_request()
    Ok(json) -> wisp.json_response(json, 201)
  }
}

pub fn user(req: Request, db: DbPool, id: String) -> Response {
  use <- wisp.require_method(req, Get)

  wisp.ok()
  |> wisp.html_body(string_tree.from_string("user with id " <> id))
}
