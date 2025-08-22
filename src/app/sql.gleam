//// This module contains the code to run the sql queries defined in
//// `./src/app/sql`.
//// > 🐿️ This module was generated automatically using v4.2.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import pog
import youid/uuid

/// Runs the `insert_user` query
/// defined in `./src/app/sql/insert_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.2.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_user(db, arg_1, arg_2, arg_3, arg_4) {
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
