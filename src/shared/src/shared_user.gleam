import gleam/dynamic/decode
import gleam/json

// UserId ----------------------------------------------------------------------
pub type UserId {
  /// Uuid on server
  UserId(v: String)
}

pub fn user_id_to_json(user_id: UserId) -> json.Json {
  json.string(user_id.v)
}

pub fn user_id_decoder() -> decode.Decoder(UserId) {
  decode.string |> decode.map(fn(v) { UserId(v) })
}

// Username ----------------------------------------------------------------------
pub type Username {
  Username(v: String)
}

pub fn username_to_json(username: Username) -> json.Json {
  json.string(username.v)
}

pub fn username_decoder() -> decode.Decoder(Username) {
  decode.string |> decode.map(fn(v) { Username(v) })
}

// UserDto ----------------------------------------------------------------------
pub type UserDto {
  UserDto(id: UserId, username: Username, email: String, email_verified: Bool)
}

pub fn decode_user_dto() -> decode.Decoder(UserDto) {
  use id <- decode.field("id", decode.string)
  use username <- decode.field("username", decode.string)
  use email <- decode.field("email", decode.string)
  use email_verified <- decode.field("email_verified", decode.bool)
  decode.success(UserDto(
    id |> UserId,
    username |> Username,
    email,
    email_verified,
  ))
}

/// {
///   "id": "0199163d-e168-753a-abb9-c09aab0123cd",
///   "username": "Tom",
///   "email": "tom@gleam.com",
///   "email_verified": false
/// }
pub fn to_json(user: UserDto) -> json.Json {
  json.object([
    #("id", json.string(user.id.v)),
    #("username", json.string(user.username.v)),
    #("email", json.string(user.email)),
    #("email_verified", json.bool(user.email_verified)),
  ])
}

// SIGNUP
// CreateUserDto  ----------------------------------------------------------------------
pub type CreateUserDto {
  CreateUserDto(username: Username, email: String, password: String)
}

pub fn decode_create_user_dto() -> decode.Decoder(CreateUserDto) {
  use username <- decode.field(
    "username",
    decode.string |> decode.map(Username),
  )
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
    #("username", json.string(create_user.username.v)),
    #("email", json.string(create_user.email)),
    #("password", json.string(create_user.password)),
  ])
}

// LOGIN
// UserLoginDto ----------------------------------------------------------------------
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

// USERS_BY_USERNAME
// UsersByUsernameDto ----------------------------------------------------------------------
pub type UsersByUsernameDto {
  UsersByUsernameDto(username: Username)
}

pub fn decode_users_by_username_dto() -> decode.Decoder(UsersByUsernameDto) {
  use username <- decode.field("username", decode.string)
  decode.success(username |> Username |> UsersByUsernameDto)
}

/// {
///   "username": "John",
/// }
pub fn users_by_username_dto_to_json(dto: UsersByUsernameDto) -> json.Json {
  json.object([
    #("username", json.string(dto.username.v)),
  ])
}

// UserMiniDto ----------------------------------------------------------------------
pub type UserMiniDto(user_id) {
  UserMiniDto(id: user_id, username: Username)
}

pub fn to_id_username_dto(value: #(UserId, Username)) -> UserMiniDto(UserId) {
  UserMiniDto(value.0, value.1)
}

pub fn decode_user_mini_dto() -> decode.Decoder(UserMiniDto(UserId)) {
  use id <- decode.field("id", decode.string)
  use username <- decode.field("username", decode.string)
  decode.success(UserMiniDto(id |> UserId, username |> Username))
}

/// {
///   "id": "0199163d-e168-753a-abb9-c09aab0123cd",
///   "username": "John",
/// }
pub fn user_mini_dto_to_json(dto: UserMiniDto(UserId)) -> json.Json {
  json.object([
    #("id", json.string(dto.id.v)),
    #("username", json.string(dto.username.v)),
  ])
}
