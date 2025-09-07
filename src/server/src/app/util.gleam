import gleam/dynamic/decode.{type Decoder}
import youid/uuid.{type Uuid}

// Helper function to decode UUID from string
pub fn decode_uuid() -> Decoder(Uuid) {
  use uuid_string <- decode.then(decode.string)
  case uuid.from_string(uuid_string) {
    Ok(uuid_value) -> decode.success(uuid_value)
    Error(_) -> decode.failure(uuid.v4(), "'" <> uuid_string <> "' not a UUID")
  }
}
