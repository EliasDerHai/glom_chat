import gleam/json
import gleeunit
import shared_user.{UserDto}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn user_json_roundtrip_test() {
  // arrange 
  let input =
    UserDto(
      "9c5b94b1-35ad-49bb-b118-8e8fc24abf80" |> shared_user.UserId,
      "John" |> shared_user.Username,
      "john.boy@gleamer.com",
      False,
    )

  // act serialize
  let actual = input |> shared_user.to_json()

  // assert serialize
  let expectation =
    json.object([
      #("id", json.string("9c5b94b1-35ad-49bb-b118-8e8fc24abf80")),
      #("username", json.string("John")),
      #("email", json.string("john.boy@gleamer.com")),
      #("email_verified", json.bool(False)),
    ])
  assert expectation == actual

  // act deserialize
  let json_text = json.to_string(actual)
  let assert Ok(actual) =
    json.parse(from: json_text, using: shared_user.decode_user_dto())

  // assert deserialize
  assert input == actual
}
