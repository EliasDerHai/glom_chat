import chat/shared_chat_id.{type ClientChatId}

pub type ChatReadConfirmationDto {
  ChatReadConfirmationDto(message_ids: List(ClientChatId))
}
