import app/persist/pool.{type DbPool}
import app/persist/sql
import app/util/query_result
import gleam/dynamic/decode
import gleam/http.{Delete, Get}
import gleam/json
import gleam/list
import gleam/result
import gleam/set.{type Set}
import pog
import shared_user.{type UserMiniDto, type Username, Username}
import wisp.{type Request, type Response}
import youid/uuid.{type Uuid}

// ################################################################################
// Value types
// ################################################################################

pub type UserId {
  UserId(v: Uuid)
}

pub fn unpack(user_id: UserId) {
  user_id.v
}

pub fn to_shared_user_id(id: UserId) -> shared_user.UserId {
  id.v |> uuid.to_string |> shared_user.UserId
}

// ################################################################################
// Entity
// ################################################################################

pub type UserEntity {
  UserEntity(
    id: UserId,
    username: Username,
    email: String,
    email_verified: Bool,
  )
}

pub fn to_dto(u: UserEntity) -> shared_user.UserDto {
  shared_user.UserDto(
    u.id |> to_shared_user_id,
    u.username,
    u.email,
    u.email_verified,
  )
}

pub fn from_select_users_row(
  el: sql.SelectUsersByUsernameRow,
) -> #(UserId, Username) {
  #(el.id |> UserId, el.username |> Username)
}

pub fn from_select_user_row(el: sql.SelectUserRow) -> UserEntity {
  UserEntity(
    el.id |> UserId,
    el.username |> Username,
    el.email,
    el.email_verified,
  )
}

// ################################################################################
// Endpoint-handler
// ################################################################################

/// GET `/users` endpoint
pub fn list_users(req: Request, db: DbPool) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  let search_username =
    decode.run(json, shared_user.decode_users_by_username_dto())
    |> result.map(fn(dto) { dto.username })
    |> result.map_error(fn(_) { "" |> Username })
    |> result.unwrap_both()

  let map_rows = fn(r: pog.Returned(sql.SelectUsersByUsernameRow)) {
    list.map(r.rows, from_select_users_row)
    |> json.array(fn(el) {
      let #(user_id, username) = el

      #(user_id.v |> uuid.to_string |> shared_user.UserId, username)
      |> shared_user.to_id_username_dto()
      |> shared_user.user_mini_dto_to_json
    })
    |> json.to_string
    |> wisp.json_response(200)
  }

  db
  |> pool.conn()
  |> sql.select_users_by_username(search_username.v, 50)
  |> query_result.map_query_result
  |> result.map(map_rows)
  |> result.unwrap_both
}

type CreateUserErrorReason {
  MalformedPayload
  ServerError
  EmailTaken
  UsernameTaken
}

/// POST `/users` endpoint
pub fn create_user(req: Request, db: DbPool) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  let result = {
    let user_id = uuid.v7()
    let conn = pog.named_connection(db.name)

    use dto <- result.try(
      decode.run(json, shared_user.decode_create_user_dto())
      |> result.map_error(fn(_) { MalformedPayload }),
    )

    use _ <- result.try(case sql.select_user_by_username(conn, dto.username.v) {
      Ok(r) if r.count >= 1 -> Error(UsernameTaken)
      _ -> Ok(Nil)
    })

    use _ <- result.try(case sql.select_user_by_email(conn, dto.email) {
      Ok(r) if r.count >= 1 -> Error(UsernameTaken)
      _ -> Ok(Nil)
    })

    use _ <- result.try(
      conn
      |> sql.create_user(
        user_id,
        dto.username.v,
        dto.email,
        False,
        dto.password,
      )
      |> result.map_error(fn(_) { ServerError }),
    )

    Ok(UserEntity(user_id |> UserId, dto.username, dto.email, False))
  }

  case result {
    Ok(entity) ->
      entity
      |> to_dto
      |> shared_user.to_json
      |> json.to_string
      |> wisp.json_response(201)

    Error(MalformedPayload) -> wisp.bad_request("bad payload")
    Error(ServerError) -> wisp.internal_server_error()
    Error(EmailTaken) -> wisp.response(400) |> wisp.string_body("email-taken")
    Error(UsernameTaken) ->
      wisp.response(400) |> wisp.string_body("username-taken")
  }
}

/// `/users/:id` endpoint
pub fn user(req: Request, db: DbPool, user_id: String) -> Response {
  {
    use user_id <- result.try(
      user_id
      |> uuid.from_string
      |> result.map_error(fn(_) { wisp.bad_request("not a uuid") })
      |> result.map(fn(v) { v |> UserId }),
    )

    case req.method {
      Get -> fetch_user(db, user_id)
      Delete -> delete_user(db, user_id)
      _ ->
        wisp.method_not_allowed([Get, Delete])
        |> Error
    }
  }
  |> result.unwrap_both
}

pub fn select_user(db: DbPool, id: UserId) -> Result(UserEntity, Response) {
  use query_result <- result.try(
    db
    |> pool.conn()
    |> sql.select_user(id.v)
    |> query_result.map_query_result,
  )

  use row <- result.try(
    query_result.rows
    |> list.first
    |> result.map_error(fn(_) { wisp.not_found() }),
  )

  row |> from_select_user_row |> Ok
}

fn fetch_user(db: DbPool, id: UserId) -> Result(Response, Response) {
  use user <- result.try(select_user(db, id))
  user
  |> to_dto
  |> shared_user.to_json
  |> json.to_string
  |> wisp.json_response(201)
  |> Ok
}

fn delete_user(db: DbPool, id: UserId) -> Result(Response, Response) {
  use query_result <- result.try(
    db
    |> pool.conn()
    |> sql.delete_user(id.v)
    |> query_result.map_query_result(),
  )

  case query_result.count {
    1 -> Ok(wisp.ok())
    _ -> Error(wisp.not_found())
  }
}

pub fn select_users_by_ids(
  db: DbPool,
  ids: Set(UserId),
) -> Result(List(UserMiniDto(UserId)), Response) {
  db
  |> pool.conn()
  |> sql.select_users_by_ids(ids |> set.map(unpack) |> set.to_list)
  |> result.map(fn(r) {
    list.map(r.rows, fn(item) {
      shared_user.UserMiniDto(item.id |> UserId, item.username |> Username)
    })
  })
  |> query_result.map_query_result()
}
