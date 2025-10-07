import chat/shared_chat.{type ClientChatMessage}
import gleam/dynamic/decode
import gleam/json.{type Json}
import shared_user.{type UserId, UserId}

pub type ServerToClientSocketMessage {
  NewMessage(message: ClientChatMessage)
  IsTyping(user: UserId)
  OnlineHasChanged(online: List(UserId))
}

pub fn to_json(socket_message: ServerToClientSocketMessage) -> Json {
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
    OnlineHasChanged(users) ->
      json.object([
        #("type", json.string("online_has_changed")),
        #("online", users |> json.array(shared_user.user_id_to_json)),
      ])
  }
}

pub fn decoder() -> decode.Decoder(ServerToClientSocketMessage) {
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
    "online_has_changed" -> {
      use online <- decode.field(
        "online",
        shared_user.user_id_decoder() |> decode.list,
      )
      decode.success(OnlineHasChanged(online:))
    }
    _ -> decode.failure(IsTyping(UserId("")), "SocketMessage")
  }
}
