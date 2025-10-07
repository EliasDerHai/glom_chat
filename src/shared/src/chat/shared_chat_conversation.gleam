import chat/shared_chat.{type ClientChatMessage}
import gleam/dynamic/decode
import gleam/json
import shared_user.{type UserId, type UserMiniDto}

pub type ChatConversationDto {
  ChatConversationDto(
    messages: List(ClientChatMessage),
    self: UserId,
    // not UserMiniDto(UserId) to already pave the way for group-chats
    others: List(UserMiniDto(UserId)),
  )
}

pub fn chat_conversation_dto_to_json(
  chat_conversation_dto: ChatConversationDto,
) -> json.Json {
  let ChatConversationDto(messages:, self:, others:) = chat_conversation_dto

  [
    #("messages", messages |> json.array(shared_chat.chat_message_to_json)),
    #("self", self |> shared_user.user_id_to_json),
    #("others", others |> json.array(shared_user.user_mini_dto_to_json)),
  ]
  |> json.object
}

pub fn chat_conversation_dto_decoder() -> decode.Decoder(ChatConversationDto) {
  use messages <- decode.field(
    "messages",
    shared_chat.chat_message_decoder() |> decode.list,
  )
  use self <- decode.field("self", shared_user.user_id_decoder())
  use others <- decode.field(
    "others",
    shared_user.decode_user_mini_dto() |> decode.list,
  )

  decode.success(ChatConversationDto(messages:, self:, others:))
}
