import app/domain/user
import app/persist/pool.{type DbPool}
import app/persist/sql
import app/util/cookie as glom_cookie
import app/util/query_result
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

fn create_session(
  db: DbPool,
  user_id: Uuid,
) -> Result(SessionEntity, pog.QueryError) {
  let session_id = uuid.v7()
  let expires_at =
    timestamp.system_time()
    |> timestamp.add(duration.seconds(day_in_seconds))

  let csrf_secret =
    crypto.strong_random_bytes(32) |> bit_array.base64_url_encode(True)

  let conn = pog.named_connection(db.name)

  use _ <- result.try(
    conn
    |> sql.create_session(session_id, user_id, expires_at, csrf_secret),
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
) -> Result(Option(SessionEntity), pog.QueryError) {
  db
  |> pool.conn()
  |> sql.select_session_by_user_id(user_id)
  |> result.map(fn(r) {
    list.first(r.rows)
    |> option.from_result
    |> option.map(from_get_session_by_user_id_row)
  })
}

fn delete_session(
  db: DbPool,
  session_id: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  db
  |> pool.conn()
  |> sql.delete_session(session_id)
}

fn cleanup_expired_sessions(
  db: DbPool,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  db
  |> pool.conn()
  |> sql.delete_expired_sessions()
}

// ################################################################################
// Endpoints
// ################################################################################

pub fn login(
  req: Request,
  db: DbPool,
  csrf_token_builder: fn(SessionEntity) -> BitArray,
  secret: BitArray,
) -> Response {
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)

  // check and cleanup expired on every login 
  // circumvents CRON or other routine for now
  let _ = cleanup_expired_sessions(db)

  case verify_user_credentials_and_create_session(db, json) {
    Error(response) -> response
    Ok(#(session, username)) -> {
      wisp.ok()
      |> glom_cookie.set_cookie(
        "session_id",
        session.id
          |> uuid.to_string
          |> bit_array.from_string
          |> crypto.sign_message(secret, crypto.Sha256),
        day_in_seconds,
        True,
      )
      |> glom_cookie.set_cookie(
        "csrf_token",
        session
          |> csrf_token_builder
          |> bit_array.base64_url_encode(False),
        day_in_seconds,
        False,
      )
      |> wisp.json_body(
        session
        |> to_session_dto(username)
        |> shared_session.to_json
        |> json.to_string,
      )
    }
  }
}

pub fn logout(req: Request, db: DbPool) -> Response {
  use <- wisp.require_method(req, Post)

  {
    use session_id <- result.try(
      wisp.get_cookie(req, "session_id", wisp.Signed)
      |> result.map_error(fn(_) {
        wisp.bad_request("no cookie with name 'session_id'")
      }),
    )

    use session_id <- result.try(
      uuid.from_string(session_id)
      |> result.map_error(fn(_) { wisp.bad_request("session_id is not valid") }),
    )

    use _ <- result.try(
      delete_session(db, session_id)
      |> query_result.map_query_result(),
    )

    wisp.ok()
    |> glom_cookie.set_cookie("session_id", "", 0, True)
    |> glom_cookie.set_cookie("csrf_token", "", 0, False)
    |> Ok
  }
  |> result.unwrap_both
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
    |> query_result.map_query_result(),
  )

  use sql.SelectUserByCredentialsRow(user_id) <- result.try(
    query_result.rows
    |> list.first
    |> result.map_error(fn(_) { wisp.response(401) }),
  )

  use old_session <- result.try(
    get_session_by_user_id(db, user_id)
    |> query_result.map_query_result(),
  )

  case old_session {
    option.None -> Nil
    option.Some(old_session) -> {
      io.println(
        "found old session for user "
        <> uuid.to_string(old_session.id)
        <> " - deleting...",
      )
      let _ = delete_session(db, old_session.id)
      Nil
    }
  }

  use session <- result.try(
    create_session(db, user_id)
    |> query_result.map_query_result(),
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

      wisp.json_response(body, 200)
    }
  }
}

pub fn get_session_from_cookie(
  db: DbPool,
  cookie_extractor: fn() -> Result(glom_cookie.Cookie, Nil),
) -> Result(SessionEntity, Response) {
  use session_id_cookie <- result.try(
    cookie_extractor()
    |> result.map_error(fn(_) {
      io.println("Failed to get session_id cookie")
      wisp.response(401)
    }),
  )

  use session_id <- result.try(
    uuid.from_string(session_id_cookie.v)
    |> result.map_error(fn(_) {
      io.println("Failed to parse session_id UUID")
      wisp.response(401)
    }),
  )

  use session <- result.try(
    get_session(db, session_id)
    |> result.map_error(fn(_) {
      io.println(
        "Failed to get session from database " <> uuid.to_string(session_id),
      )
      wisp.response(401)
    }),
  )

  Ok(session)
}
