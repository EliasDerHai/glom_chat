import gleam/dynamic/decode
import gleam/json
import gleam/time/timestamp.{type Timestamp}
import shared_user.{type UserId}

pub type SessionId {
  /// Uuid on server
  SessionId(v: String)
}

pub type SessionDto {
  SessionDto(id: SessionId, user_id: UserId, expires_at: Timestamp)
}

pub fn decode_user_dto() -> decode.Decoder(SessionDto) {
  use id <- decode.field("id", decode.string)
  use user_id <- decode.field("user_id", decode.string)
  use expires_at <- decode.field("expires_at", decode.int)

  SessionDto(
    id |> SessionId,
    user_id |> shared_user.UserId,
    expires_at |> timestamp.from_unix_seconds,
  )
  |> decode.success
}

/// {
///   "id": "0199163d-e168-753a-abb9-c09aab0123cd",
///   "user_id": "0199163d-e168-753a-abb9-c09aab0123cd",
///   "expires_at": 192859999823
/// }
pub fn to_json(dto: SessionDto) -> json.Json {
  json.object([
    #("id", dto.id.v |> json.string()),
    #("user_id", dto.user_id.v |> json.string()),
    #(
      "expires_at",
      dto.expires_at
        |> timestamp.to_unix_seconds
        |> json.float,
    ),
  ])
}
