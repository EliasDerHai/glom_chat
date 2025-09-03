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
pub fn select_user(db, arg_1) {
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

/// A row you get from running the `verify_user_credentials` query
/// defined in `./src/app/persist/sql/verify_user_credentials.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.2.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type VerifyUserCredentialsRow {
  VerifyUserCredentialsRow(id: Uuid)
}

/// Runs the `verify_user_credentials` query
/// defined in `./src/app/persist/sql/verify_user_credentials.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn verify_user_credentials(db, arg_1, arg_2) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    decode.success(VerifyUserCredentialsRow(id:))
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
