import app/domain/user
import app/persist/pool.{type DbPool}
import app/persist/sql
import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import pog
import shared_session.{type SessionDto, SessionDto}
import shared_user.{type Username}
import wisp.{type Request, type Response}
import youid/uuid.{type Uuid}

// ################################################################################
// Entity
// ################################################################################

// NOTE: session doesn't have to live in /shared package since it's a server only concept. only the session_id ever gets sent to client but as session_cookie not as json
pub type SessionEntity {
  SessionEntity(
    id: Uuid,
    user_id: Uuid,
    expires_at: timestamp.Timestamp,
    csrf_secret: String,
  )
}

pub fn to_session_dto(entity: SessionEntity, username: Username) -> SessionDto {
  SessionDto(
    entity.id |> uuid.to_string |> shared_session.SessionId,
    entity.user_id |> uuid.to_string |> shared_user.UserId,
    username,
    entity.expires_at,
  )
}

pub fn from_get_session_row(row: sql.SelectSessionByIdRow) -> SessionEntity {
  SessionEntity(
    id: row.id,
    user_id: row.user_id,
    expires_at: row.expires_at,
    csrf_secret: row.csrf_secret,
  )
}

pub fn from_get_session_by_user_id_row(
  row: sql.SelectSessionByUserIdRow,
) -> SessionEntity {
  SessionEntity(
    id: row.id,
    user_id: row.user_id,
    expires_at: row.expires_at,
    csrf_secret: row.csrf_secret,
  )
}

// ################################################################################
// Session Management
// ################################################################################

const day_in_seconds = 86_400

fn create_session(db: DbPool, user_id: Uuid) -> Result(SessionEntity, Nil) {
  let session_id = uuid.v7()
  let expires_at =
    timestamp.system_time()
    |> timestamp.add(duration.seconds(day_in_seconds))

  let csrf_secret =
    crypto.strong_random_bytes(32) |> bit_array.base64_url_encode(True)

  let conn = pog.named_connection(db.name)

  use _ <- result.try(
    conn
    |> sql.create_session(session_id, user_id, expires_at, csrf_secret)
    |> result.map_error(fn(_) { Nil }),
  )

  Ok(SessionEntity(session_id, user_id, expires_at, csrf_secret))
}

pub fn get_session(db: DbPool, session_id: Uuid) -> Result(SessionEntity, Nil) {
  use query_result <- result.try(
    db
    |> pool.conn()
    |> sql.select_session_by_id(session_id)
    |> result.map_error(fn(_) { Nil }),
  )

  use row <- result.try(
    query_result.rows
    |> list.first
    |> result.map_error(fn(_) { Nil }),
  )

  Ok(from_get_session_row(row))
}

fn get_session_by_user_id(
  db: DbPool,
  user_id: Uuid,
) -> Result(Option(SessionEntity), Nil) {
  db
  |> pool.conn()
  |> sql.select_session_by_user_id(user_id)
  |> result.map(fn(r) {
    list.first(r.rows)
    |> option.from_result
    |> option.map(from_get_session_by_user_id_row)
  })
  |> result.map_error(fn(_) { Nil })
}

fn delete_session(db: DbPool, session_id: Uuid) -> Result(Nil, Nil) {
  db
  |> pool.conn()
  |> sql.delete_session(session_id)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(_) { Nil })
}

fn cleanup_expired_sessions(db: DbPool) -> Result(Nil, Nil) {
  db
  |> pool.conn()
  |> sql.delete_expired_sessions()
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(_) { Nil })
}

// ################################################################################
// Endpoints
// ################################################################################

pub fn login(
  req: Request,
  db: DbPool,
  csrf_token_builder: fn(SessionEntity) -> BitArray,
) -> Response {
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)

  // check and cleanup expired on every login 
  // circumvents CRON or other routine for now
  let _ = cleanup_expired_sessions(db)

  case verify_user_credentials_and_create_session(db, json) {
    Error(response) -> response
    Ok(#(session, username)) ->
      wisp.ok()
      |> wisp.set_cookie(
        req,
        "session_id",
        uuid.to_string(session.id),
        wisp.Signed,
        day_in_seconds,
      )
      |> wisp.set_cookie(
        req,
        "csrf_token",
        session
          |> csrf_token_builder
          |> bit_array.base64_url_encode(False),
        wisp.PlainText,
        day_in_seconds,
      )
      |> wisp.json_body(
        session
        |> to_session_dto(username)
        |> shared_session.to_json
        |> json.to_string,
      )
  }
}

pub fn logout(req: Request, db: DbPool) -> Response {
  use <- wisp.require_method(req, Post)

  case wisp.get_cookie(req, "session_id", wisp.Signed) {
    Ok(session_id_str) ->
      case uuid.from_string(session_id_str) {
        Ok(session_id) -> {
          let _ = delete_session(db, session_id)

          wisp.ok()
          |> wisp.set_cookie(req, "session_id", "", wisp.Signed, 0)
          |> wisp.set_cookie(req, "csrf_token", "", wisp.PlainText, 0)
        }
        Error(_) -> wisp.bad_request("session_id is not a uuid")
      }
    Error(_) -> wisp.bad_request("no cookie with name 'session_id'")
  }
}

fn verify_user_credentials_and_create_session(
  db: DbPool,
  json: dynamic.Dynamic,
) -> Result(#(SessionEntity, Username), Response) {
  use dto <- result.try(
    decode.run(json, shared_user.decode_user_login_dto())
    |> result.map_error(fn(_) {
      wisp.bad_request(
        "bad login dto - should be like `{\"username\": \"Joe\", \"password\": \"pa$$word\"}`",
      )
    }),
  )

  use query_result <- result.try(
    db
    |> pool.conn()
    |> sql.select_user_by_credentials(dto.username, dto.password)
    |> result.map_error(fn(_) { wisp.internal_server_error() }),
  )

  use sql.SelectUserByCredentialsRow(user_id) <- result.try(
    query_result.rows
    |> list.first
    |> result.map_error(fn(_) { wisp.response(401) }),
  )

  use old_session <- result.try(
    get_session_by_user_id(db, user_id)
    |> result.map_error(fn(_) { wisp.internal_server_error() }),
  )

  case old_session {
    option.None -> Nil
    option.Some(old_session) -> {
      io.println(
        "found old session for user "
        <> uuid.to_string(old_session.id)
        <> " - deleting...",
      )
      delete_session(db, old_session.id) |> result.unwrap_both
    }
  }

  use session <- result.try(
    create_session(db, user_id)
    |> result.map_error(fn(_) { wisp.internal_server_error() }),
  )

  Ok(#(session, dto.username |> shared_user.Username))
}

pub fn me(req: Request, db: DbPool, session: SessionEntity) -> Response {
  use <- wisp.require_method(req, http.Get)

  case user.select_user(db, session.user_id) {
    Error(e) -> e
    Ok(user_entity) -> {
      let body =
        session
        |> to_session_dto(user_entity.username)
        |> shared_session.to_json
        |> json.to_string

      wisp.json_body(wisp.ok(), body)
    }
  }
}
