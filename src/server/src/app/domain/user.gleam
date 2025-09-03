import app/persist/pool.{type DbPool}
import app/persist/sql
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post}
import gleam/json
import gleam/list
import gleam/result
import pog
import wisp.{type Request, type Response}
import youid/uuid.{type Uuid}

// ################################################################################
// Entity
// ################################################################################

pub type UserEntity {
  UserEntity(id: Uuid, username: String, email: String, email_verified: Bool)
}

pub fn to_json(user: UserEntity) -> json.Json {
  json.object([
    #("id", uuid.to_string(user.id) |> json.string()),
    #("username", json.string(user.username)),
    #("email", json.string(user.email)),
    #("email_verified", json.bool(user.email_verified)),
  ])
}

pub fn from_select_users_row(el: sql.SelectUsersRow) -> UserEntity {
  UserEntity(el.id, el.username, el.email, el.email_verified)
}

pub fn from_select_user_row(el: sql.SelectUserRow) -> UserEntity {
  UserEntity(el.id, el.username, el.email, el.email_verified)
}

// ################################################################################
// Dto
// ################################################################################

/// {
///   "username": "John",
///   "email": "john.boy@gleam.com"
/// }
pub type CreateUserDto {
  CreateUserDto(username: String, email: String, password: String)
}

fn decode_user() -> decode.Decoder(CreateUserDto) {
  use username <- decode.field("username", decode.string)
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(CreateUserDto(username:, email:, password:))
}

/// {
///   "username": "John",
///   "password": "s7490$@2xx03"
/// }
pub type UserLoginDto {
  UserLoginDto(username: String, password: String)
}

fn decode_user_login() -> decode.Decoder(UserLoginDto) {
  use username <- decode.field("username", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(UserLoginDto(username:, password:))
}

// ################################################################################
// Endpoint-handler
// ################################################################################

/// `/users` endpoint
pub fn users(req: Request, db: DbPool) -> Response {
  case req.method {
    Get -> list_users(db)
    Post -> create_user(req, db)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_users(db: DbPool) -> Response {
  case
    db
    |> pool.conn()
    |> sql.select_users(100, 0)
  {
    Error(_) -> wisp.internal_server_error()
    Ok(r) -> {
      list.map(r.rows, from_select_users_row)
      |> json.array(fn(el) { el |> to_json })
      |> json.to_string_tree
      |> wisp.json_response(200)
    }
  }
}

fn create_user(req: Request, db: DbPool) -> Response {
  use json <- wisp.require_json(req)

  let result = {
    let user_id = uuid.v7()
    let conn = pog.named_connection(db.name)

    use dto <- result.try(
      decode.run(json, decode_user()) |> result.map_error(fn(_) { Nil }),
    )

    use _ <- result.try(
      conn
      |> sql.create_user(user_id, dto.username, dto.email, False, dto.password)
      |> result.map_error(fn(_) { Nil }),
    )

    Ok(UserEntity(user_id, dto.username, dto.email, False))
  }

  case result {
    Error(_) -> wisp.bad_request()
    Ok(entity) ->
      to_json(entity) |> json.to_string_tree |> wisp.json_response(201)
  }
}

/// `/users/:id` endpoint
pub fn user(req: Request, db: DbPool, id_str: String) -> Response {
  {
    use id <- result.try(
      uuid.from_string(id_str)
      |> result.map_error(fn(_) { wisp.bad_request() }),
    )

    case req.method {
      Get -> fetch_user(db, id)
      Delete -> delete_user(db, id)
      _ ->
        wisp.method_not_allowed([Get, Delete])
        |> Error
    }
  }
  |> result.unwrap_both
}

/// `/users/auth` endpoint
pub fn auth(req: Request, db: DbPool) -> Response {
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)

  verify_user_credentials(db, json) |> result.unwrap_both
}

fn verify_user_credentials(
  db: DbPool,
  json: dynamic.Dynamic,
) -> Result(Response, Response) {
  use dto <- result.try(
    decode.run(json, decode_user_login())
    |> result.map_error(fn(_) { wisp.bad_request() }),
  )

  use query_result <- result.try(
    db
    |> pool.conn()
    |> sql.verify_user_credentials(dto.username, dto.password)
    |> result.map_error(fn(_) { wisp.internal_server_error() }),
  )

  use sql.VerifyUserCredentialsRow(user_id) <- result.try(
    query_result.rows
    |> list.first
    |> result.map_error(fn(_) { wisp.not_found() }),
  )

  user_id
  |> uuid.to_string
  |> json.string
  |> json.to_string_tree
  |> wisp.json_response(201)
  |> Ok
}

fn fetch_user(db: DbPool, id: Uuid) -> Result(Response, Response) {
  use query_result <- result.try(
    db
    |> pool.conn()
    |> sql.select_user(id)
    |> result.map_error(fn(_) { wisp.internal_server_error() }),
  )

  use row <- result.try(
    query_result.rows
    |> list.first
    |> result.map_error(fn(_) { wisp.not_found() }),
  )

  row
  |> from_select_user_row
  |> to_json
  |> json.to_string_tree
  |> wisp.json_response(201)
  |> Ok
}

fn delete_user(db: DbPool, id: Uuid) -> Result(Response, Response) {
  use query_result <- result.try(
    db
    |> pool.conn()
    |> sql.delete_user(id)
    |> result.map_error(fn(_) { wisp.internal_server_error() }),
  )

  case query_result.count {
    1 -> Ok(wisp.ok())
    _ -> Error(wisp.not_found())
  }
}
