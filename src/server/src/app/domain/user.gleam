import app/environment
import app/persist/pool.{type DbPool}
import app/persist/sql
import app/util/mailing
import app/util/query_result
import gleam/dynamic/decode
import gleam/http.{Delete, Get}
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import pog
import shared_user.{type UserMiniDto, type Username, Username}
import util/result_extension
import util/tuple
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

pub fn from_shared_user_id(id: shared_user.UserId) -> Result(UserId, Nil) {
  id.v
  |> uuid.from_string
  |> result.map(fn(uuid) { uuid |> UserId })
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
    |> result_extension.unwrap_both()

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
  |> result_extension.unwrap_both
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
    let user_id = uuid.v7() |> UserId

    // not uuid.v7() bc pseudo rand num could be close or match user_id
    // it's probably unnecessary but otherwise malicious actors might 
    // be able to confirm the user's email without actually receiving 
    // the mail
    let email_confirmation_hash =
      timestamp.system_time()
      |> timestamp.add(duration.milliseconds(-1 * int.random(10_000)))
      |> timestamp.to_unix_seconds_and_nanoseconds
      |> tuple.map(fn(s, ms) { s * 1000 + ms })
      |> uuid.v7_from_millisec()

    let conn = db |> pool.conn

    use dto <- result.try(
      decode.run(json, shared_user.decode_create_user_dto())
      |> result.map_error(fn(_) { MalformedPayload }),
    )

    // unique checks
    use _ <- result.try(case sql.select_user_by_username(conn, dto.username.v) {
      Ok(r) if r.count >= 1 -> Error(UsernameTaken)
      _ -> Ok(Nil)
    })

    use _ <- result.try(case sql.select_user_by_email(conn, dto.email) {
      Ok(r) if r.count >= 1 -> Error(UsernameTaken)
      _ -> Ok(Nil)
    })

    // credential check
    use _ <- result.try(
      // FIXME: revert/rollback if email sending fails
      sql.insert_user(
        conn,
        user_id.v,
        dto.username.v,
        dto.email,
        False,
        dto.password,
        email_confirmation_hash,
      )
      |> query_result.map_query_result_expect_single_row()
      |> result.map_error(fn(_) { ServerError }),
    )

    use _ <- result.try(case environment.is_prod() {
      // send mail for email confirmation
      True -> {
        // server_url:8080/api/email/confirm/user_id/email_confirmation_hash
        let confirm_url =
          [
            environment.get_server_base_url(),
            "api",
            "email",
            "confirm",
            user_id.v |> uuid.to_string,
            email_confirmation_hash |> uuid.to_string,
          ]
          |> string.join("/")

        wisp.log_info(
          "sending mail to '" <> dto.email <> "' with '" <> confirm_url <> "'",
        )

        mailing.send_confirmation_mail(dto.email, confirm_url)

        Ok(Nil)
      }

      // skip mail confirmation and update db immediately
      False -> {
        wisp.log_info("skip sending mail to '" <> dto.email <> "' (dev-env)")

        sql.update_user_email_verified(
          db |> pool.conn,
          user_id.v,
          email_confirmation_hash,
        )
        |> query_result.map_query_result_expect_single_row()
        |> result.map_error(fn(_) { ServerError })
        |> result.map(fn(_) { Nil })
      }
    })

    Ok(UserEntity(user_id, dto.username, dto.email, False))
  }

  // response
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
  |> result_extension.unwrap_both
}

/// `/email/:id/:hash` endpoint
pub fn confirm_email(
  req: Request,
  db: DbPool,
  user_id: String,
  hash: String,
) -> Response {
  use <- wisp.require_method(req, http.Get)
  {
    use user_id <- result.try(
      user_id
      |> uuid.from_string
      |> result.map_error(fn(_) { wisp.bad_request("not a uuid") })
      |> result.map(fn(v) { v |> UserId }),
    )

    use hash <- result.try(
      hash
      |> uuid.from_string
      |> result.map_error(fn(_) { wisp.bad_request("not a uuid") }),
    )

    use res <- result.try(
      sql.update_user_email_verified(db |> pool.conn, user_id.v, hash)
      |> query_result.map_query_result,
    )

    case res.count == 1 {
      False -> Error(wisp.response(401))
      True -> wisp.ok() |> Ok
    }
  }
  |> result_extension.unwrap_both
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

pub fn to_shared_user_mini(
  dto: UserMiniDto(UserId),
) -> UserMiniDto(shared_user.UserId) {
  shared_user.UserMiniDto(dto.id |> to_shared_user_id, dto.username)
}
