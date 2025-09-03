import app/domain/entity
import app/domain/user
import gleam/json
import gleeunit
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn user_to_json_test() {
  // arrange 
  let id = uuid.v7()
  let input = entity.UserEntity(id, "John", "john.boy@gleamer.com", False)

  // act
  let actual = input |> user.to_json()

  // assert
  let expecation =
    json.object([
      #("id", uuid.to_string(id) |> json.string()),
      #("username", json.string("John")),
      #("email", json.string("john.boy@gleamer.com")),
      #("email_verified", json.bool(False)),
    ])
  assert expecation == actual
}
