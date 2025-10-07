import gleam/dynamic/decode
import gleam/json
import shared_user.{type UserId}

pub type ChatMessageCreationDto {
  ChatMessageCreationDto(receiver: UserId, text_content: List(String))
}

pub fn decoder() -> decode.Decoder(ChatMessageCreationDto) {
  use receiver <- decode.field("receiver", shared_user.user_id_decoder())
  use text_content <- decode.field("text_content", decode.list(decode.string))
  decode.success(ChatMessageCreationDto(receiver:, text_content:))
}

pub fn to_json(chat_message_creation_dto: ChatMessageCreationDto) -> json.Json {
  let ChatMessageCreationDto(receiver:, text_content:) =
    chat_message_creation_dto
  json.object([
    #("receiver", receiver |> shared_user.user_id_to_json()),
    #("text_content", json.array(text_content, json.string)),
  ])
}
