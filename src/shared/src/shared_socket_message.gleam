import gleam/dynamic/decode
import gleam/json.{type Json}
import shared_chat.{type ClientChatMessage}
import shared_user.{type UserId, UserId}

pub type SocketMessage {
  NewMessage(message: ClientChatMessage)
  IsTyping(user: UserId)
}

pub fn socket_message_to_json(socket_message: SocketMessage) -> Json {
  case socket_message {
    NewMessage(message:) ->
      json.object([
        #("type", json.string("new_message")),
        #("message", message |> shared_chat.chat_message_to_json()),
      ])
    IsTyping(user:) ->
      json.object([
        #("type", json.string("is_typing")),
        #("user", user |> shared_user.user_id_to_json()),
      ])
  }
}

pub fn socket_message_decoder() -> decode.Decoder(SocketMessage) {
  use variant <- decode.field("type", decode.string)

  case variant {
    "new_message" -> {
      use message <- decode.field("message", shared_chat.chat_message_decoder())
      decode.success(NewMessage(message:))
    }
    "is_typing" -> {
      use user <- decode.field("user", shared_user.user_id_decoder())
      decode.success(IsTyping(user:))
    }
    _ -> decode.failure(IsTyping(UserId("")), "SocketMessage")
  }
}
