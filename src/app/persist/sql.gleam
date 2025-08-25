//// This module contains the code to run the sql queries defined in
//// `./src/app/persist/sql`.
//// > 🐿️ This module was generated automatically using v4.2.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import pog
import youid/uuid.{type Uuid}

/// Runs the `create_user` query
/// defined in `./src/app/persist/sql/create_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(db, arg_1, arg_2, arg_3, arg_4) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO users (id, user_name, email, email_verified)
VALUES ($1, $2, $3, $4);
"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.bool(arg_4))
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
    user_name: String,
    email: String,
    email_verified: Bool,
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
    use user_name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    use email_verified <- decode.field(3, decode.bool)
    decode.success(SelectUserRow(id:, user_name:, email:, email_verified:))
  }

  "SELECT * FROM users WHERE id = $1;
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
    user_name: String,
    email: String,
    email_verified: Bool,
  )
}

/// Runs the `select_users` query
/// defined in `./src/app/persist/sql/select_users.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn select_users(db) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use user_name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    use email_verified <- decode.field(3, decode.bool)
    decode.success(SelectUsersRow(id:, user_name:, email:, email_verified:))
  }

  "SELECT * FROM users;
"
  |> pog.query
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
