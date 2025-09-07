import gleam/dynamic/decode
import gleam/json

// ENTITY 

pub type UserDto {
  UserDto(id: String, username: String, email: String, email_verified: Bool)
}

pub fn decode_user_dto() -> decode.Decoder(UserDto) {
  use id <- decode.field("id", decode.string)
  use username <- decode.field("username", decode.string)
  use email <- decode.field("email", decode.string)
  use email_verified <- decode.field("email_verified", decode.bool)
  decode.success(UserDto(id, username, email, email_verified))
}

/// {
///   "id": "0199163d-e168-753a-abb9-c09aab0123cd",
///   "username": "Tom",
///   "email": "tom@gleam.com",
///   "email_verified": false
/// }
pub fn to_json(user: UserDto) -> json.Json {
  json.object([
    #("id", json.string(user.id)),
    #("username", json.string(user.username)),
    #("email", json.string(user.email)),
    #("email_verified", json.bool(user.email_verified)),
  ])
}

// SIGNUP

pub type CreateUserDto {
  CreateUserDto(username: String, email: String, password: String)
}

pub fn decode_create_user_dto() -> decode.Decoder(CreateUserDto) {
  use username <- decode.field("username", decode.string)
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(CreateUserDto(username:, email:, password:))
}

/// {
///   "username": "John",
///   "email": "john.boy@gleam.com"
///   "password": "12345",
/// }
pub fn create_user_dto_to_json(create_user: CreateUserDto) -> json.Json {
  json.object([
    #("username", json.string(create_user.username)),
    #("email", json.string(create_user.email)),
    #("password", json.string(create_user.password)),
  ])
}

// LOGIN

pub type UserLoginDto {
  UserLoginDto(username: String, password: String)
}

pub fn decode_user_login_dto() -> decode.Decoder(UserLoginDto) {
  use username <- decode.field("username", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(UserLoginDto(username:, password:))
}

/// {
///   "username": "John",
///   "email": "john.boy@gleam.com"
/// }
pub fn user_loging_dto_to_json(user_login: UserLoginDto) -> json.Json {
  json.object([
    #("username", json.string(user_login.username)),
    #("password", json.string(user_login.password)),
  ])
}
