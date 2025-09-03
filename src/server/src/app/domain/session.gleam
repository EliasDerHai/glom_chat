import app/auth
import app/domain/entity.{type SessionEntity, SessionEntity}
import app/persist/pool.{type DbPool}
import app/persist/sql
import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/http.{Post}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import pog
import wisp.{type Request, type Response}
import youid/uuid.{type Uuid}

// ################################################################################
// Entity
// ################################################################################

pub fn from_get_session_row(row: sql.GetSessionByIdRow) -> SessionEntity {
  SessionEntity(
    id: row.id,
    user_id: row.user_id,
    expires_at: row.expires_at,
    csrf_secret: row.csrf_secret,
  )
}

pub fn from_get_session_by_user_id_row(
  row: sql.GetSessionByUserIdRow,
) -> SessionEntity {
  SessionEntity(
    id: row.id,
    user_id: row.user_id,
    expires_at: row.expires_at,
    csrf_secret: row.csrf_secret,
  )
}

// ################################################################################
// DTOs
// ################################################################################

type UserLoginDto {
  UserLoginDto(username: String, password: String)
}

fn decode_user_login() -> decode.Decoder(UserLoginDto) {
  use username <- decode.field("username", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(UserLoginDto(username:, password:))
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

fn get_session(db: DbPool, session_id: Uuid) -> Result(SessionEntity, Nil) {
  use query_result <- result.try(
    db
    |> pool.conn()
    |> sql.get_session_by_id(session_id)
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
  |> sql.get_session_by_user_id(user_id)
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
  |> sql.cleanup_expired_sessions()
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(_) { Nil })
}

// ################################################################################
// Endpoints
// ################################################################################

pub fn login(req: Request, db: DbPool) -> Response {
  use <- wisp.require_method(req, Post)
  use json <- wisp.require_json(req)

  case verify_user_credentials_and_create_session(db, json) {
    Ok(session) -> {
      let csrf_token =
        auth.generate_csrf_token(session) |> bit_array.base64_url_encode(False)

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
        csrf_token,
        wisp.PlainText,
        day_in_seconds,
      )
      |> wisp.set_header("content-type", "application/json")
    }
    Error(response) -> response
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
        Error(_) -> wisp.bad_request()
      }
    Error(_) -> wisp.bad_request()
  }
}

// ################################################################################
// Helper Functions
// ################################################################################

pub fn get_session_from_cookie(
  req: Request,
  db: DbPool,
) -> Result(SessionEntity, Response) {
  use session_id_str <- result.try(
    wisp.get_cookie(req, "session_id", wisp.Signed)
    |> result.map_error(fn(_) {
      io.println("Failed to get session_id cookie")
      wisp.response(401)
    }),
  )

  use session_id <- result.try(
    uuid.from_string(session_id_str)
    |> result.map_error(fn(_) {
      io.println("Failed to parse session_id UUID")
      wisp.response(401)
    }),
  )

  use session <- result.try(
    get_session(db, session_id)
    |> result.map_error(fn(_) {
      io.println("Failed to get session from database")
      wisp.response(401)
    }),
  )

  Ok(session)
}

fn verify_user_credentials_and_create_session(
  db: DbPool,
  json: dynamic.Dynamic,
) -> Result(SessionEntity, Response) {
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
    |> result.map_error(fn(_) { wisp.response(503) }),
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

  Ok(session)
}

pub fn me(req: Request, db: DbPool) -> Response {
  use <- wisp.require_method(req, http.Get)

  case get_session_from_cookie(req, db) {
    Ok(session) -> {
      wisp.ok()
      |> wisp.json_body(
        json.object([
          #("authenticated", json.bool(True)),
          #("user_id", uuid.to_string(session.user_id) |> json.string()),
          #("session_id", uuid.to_string(session.id) |> json.string()),
          #(
            "expires_at",
            float.round(timestamp.to_unix_seconds(session.expires_at) *. 1000.0)
              |> json.int(),
          ),
        ])
        |> json.to_string_tree,
      )
    }
    Error(response) -> response
  }
}
