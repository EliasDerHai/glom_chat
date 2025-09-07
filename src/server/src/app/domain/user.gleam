import app/persist/pool.{type DbPool}
import app/persist/sql
import gleam/dynamic/decode
import gleam/http.{Delete, Get}
import gleam/json
import gleam/list
import gleam/result
import pog
import shared_user
import wisp.{type Request, type Response}
import youid/uuid.{type Uuid}

// ################################################################################
// Entity
// ################################################################################

pub type UserEntity {
  UserEntity(id: Uuid, username: String, email: String, email_verified: Bool)
}

pub fn to_dto(u: UserEntity) -> shared_user.UserDto {
  shared_user.UserDto(
    uuid.to_string(u.id),
    u.username,
    u.email,
    u.email_verified,
  )
}

pub fn from_select_users_row(el: sql.SelectUsersRow) -> UserEntity {
  UserEntity(el.id, el.username, el.email, el.email_verified)
}

pub fn from_select_user_row(el: sql.SelectUserRow) -> UserEntity {
  UserEntity(el.id, el.username, el.email, el.email_verified)
}

// ################################################################################
// Endpoint-handler
// ################################################################################

/// GET `/users` endpoint
pub fn list_users(db: DbPool) -> Response {
  case
    db
    |> pool.conn()
    |> sql.select_users(100, 0)
  {
    Error(_) -> wisp.internal_server_error()
    Ok(r) -> {
      list.map(r.rows, from_select_users_row)
      |> json.array(fn(el) { el |> to_dto |> shared_user.to_json })
      |> json.to_string_tree
      |> wisp.json_response(200)
    }
  }
}

/// POST `/users` endpoint
pub fn create_user(req: Request, db: DbPool) -> Response {
  use json <- wisp.require_json(req)

  let result = {
    let user_id = uuid.v7()
    let conn = pog.named_connection(db.name)

    use dto <- result.try(
      decode.run(json, shared_user.decode_create_user_dto())
      |> result.map_error(fn(_) { Nil }),
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
      entity
      |> to_dto
      |> shared_user.to_json
      |> json.to_string_tree
      |> wisp.json_response(201)
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
  |> to_dto
  |> shared_user.to_json
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
