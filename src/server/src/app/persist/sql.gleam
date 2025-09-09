//// This module contains the code to run the sql queries defined in
//// `./src/app/persist/sql`.
//// > 🐿️ This module was generated automatically using v4.2.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog
import youid/uuid.{type Uuid}

/// Runs the `create_session` query
/// defined in `./src/app/persist/sql/create_session.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_session(db, arg_1, arg_2, arg_3, arg_4) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO sessions (id, user_id, expires_at, csrf_secret)
VALUES ($1, $2, $3, $4);"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `create_user` query
/// defined in `./src/app/persist/sql/create_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(db, arg_1, arg_2, arg_3, arg_4, arg_5) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO users (id, username, email, email_verified, password_hash)
VALUES ($1, $2, $3, $4, crypt($5, gen_salt('bf', 12)));
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.bool(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_expired_sessions` query
/// defined in `./src/app/persist/sql/delete_expired_sessions.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_expired_sessions(db) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM sessions WHERE expires_at <= now();
"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_session` query
/// defined in `./src/app/persist/sql/delete_session.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_session(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM sessions WHERE id = $1;"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_user` query
/// defined in `./src/app/persist/sql/delete_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_user(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM users WHERE id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `select_session_by_id` query
/// defined in `./src/app/persist/sql/select_session_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SelectSessionByIdRow {
  SelectSessionByIdRow(
    id: Uuid,
    user_id: Uuid,
    created_at: Timestamp,
    expires_at: Timestamp,
    csrf_secret: String,
  )
}

/// Runs the `select_session_by_id` query
/// defined in `./src/app/persist/sql/select_session_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn select_session_by_id(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(SelectSessionByIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use user_id <- decode.field(1, uuid_decoder())
    use created_at <- decode.field(2, pog.timestamp_decoder())
    use expires_at <- decode.field(3, pog.timestamp_decoder())
    use csrf_secret <- decode.field(4, decode.string)
    decode.success(SelectSessionByIdRow(
      id:,
      user_id:,
      created_at:,
      expires_at:,
      csrf_secret:,
    ))
  }

  "SELECT id, user_id, created_at, expires_at, csrf_secret
FROM sessions 
WHERE id = $1 AND expires_at > now();
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `select_session_by_user_id` query
/// defined in `./src/app/persist/sql/select_session_by_user_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SelectSessionByUserIdRow {
  SelectSessionByUserIdRow(
    id: Uuid,
    user_id: Uuid,
    created_at: Timestamp,
    expires_at: Timestamp,
    csrf_secret: String,
  )
}

/// Runs the `select_session_by_user_id` query
/// defined in `./src/app/persist/sql/select_session_by_user_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn select_session_by_user_id(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use user_id <- decode.field(1, uuid_decoder())
    use created_at <- decode.field(2, pog.timestamp_decoder())
    use expires_at <- decode.field(3, pog.timestamp_decoder())
    use csrf_secret <- decode.field(4, decode.string)
    decode.success(SelectSessionByUserIdRow(
      id:,
      user_id:,
      created_at:,
      expires_at:,
      csrf_secret:,
    ))
  }

  "SELECT id, user_id, created_at, expires_at, csrf_secret
FROM sessions 
WHERE user_id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `select_user` query
/// defined in `./src/app/persist/sql/select_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SelectUserRow {
  SelectUserRow(
    id: Uuid,
    username: String,
    email: String,
    email_verified: Bool,
    last_login: Option(Timestamp),
    failed_logins: Int,
  )
}

/// Runs the `select_user` query
/// defined in `./src/app/persist/sql/select_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn select_user(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(SelectUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use username <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    use email_verified <- decode.field(3, decode.bool)
    use last_login <- decode.field(4, decode.optional(pog.timestamp_decoder()))
    use failed_logins <- decode.field(5, decode.int)
    decode.success(SelectUserRow(
      id:,
      username:,
      email:,
      email_verified:,
      last_login:,
      failed_logins:,
    ))
  }

  "SELECT id, username, email, email_verified, last_login, failed_logins FROM users WHERE id = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `select_user_by_credentials` query
/// defined in `./src/app/persist/sql/select_user_by_credentials.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SelectUserByCredentialsRow {
  SelectUserByCredentialsRow(id: Uuid)
}

/// Runs the `select_user_by_credentials` query
/// defined in `./src/app/persist/sql/select_user_by_credentials.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn select_user_by_credentials(db, arg_1, arg_2) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    decode.success(SelectUserByCredentialsRow(id:))
  }

  "SELECT id
FROM users
WHERE username = $1
  AND password_hash = crypt($2, password_hash);
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `select_user_by_email` query
/// defined in `./src/app/persist/sql/select_user_by_email.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SelectUserByEmailRow {
  SelectUserByEmailRow(id: Uuid)
}

/// Runs the `select_user_by_email` query
/// defined in `./src/app/persist/sql/select_user_by_email.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn select_user_by_email(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    decode.success(SelectUserByEmailRow(id:))
  }

  "SELECT id FROM users WHERE email = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `select_user_by_username` query
/// defined in `./src/app/persist/sql/select_user_by_username.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SelectUserByUsernameRow {
  SelectUserByUsernameRow(id: Uuid)
}

/// Runs the `select_user_by_username` query
/// defined in `./src/app/persist/sql/select_user_by_username.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn select_user_by_username(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    decode.success(SelectUserByUsernameRow(id:))
  }

  "SELECT id FROM users WHERE username = $1;
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `select_users` query
/// defined in `./src/app/persist/sql/select_users.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type SelectUsersRow {
  SelectUsersRow(
    id: Uuid,
    username: String,
    email: String,
    email_verified: Bool,
    last_login: Option(Timestamp),
    failed_logins: Int,
  )
}

/// Runs the `select_users` query
/// defined in `./src/app/persist/sql/select_users.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn select_users(db, arg_1, arg_2) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use username <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    use email_verified <- decode.field(3, decode.bool)
    use last_login <- decode.field(4, decode.optional(pog.timestamp_decoder()))
    use failed_logins <- decode.field(5, decode.int)
    decode.success(SelectUsersRow(
      id:,
      username:,
      email:,
      email_verified:,
      last_login:,
      failed_logins:,
    ))
  }

  "SELECT id, username, email, email_verified, last_login, failed_logins FROM users ORDER BY ID LIMIT $1 OFFSET $2;
"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.int(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Encoding/decoding utils -------------------------------------------------

/// A decoder to decode `Uuid`s coming from a Postgres query.
///
fn uuid_decoder() {
  use bit_array <- decode.then(decode.bit_array)
  case uuid.from_bit_array(bit_array) {
    Ok(uuid) -> decode.success(uuid)
    Error(_) -> decode.failure(uuid.v7(), "Uuid")
  }
}
