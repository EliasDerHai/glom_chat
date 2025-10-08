import chat/shared_chat.{type ClientChatMessage}
import chat/shared_chat_confirmation.{type ChatConfirmation}
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import shared_user.{type UserId, UserId}

pub type ServerToClientSocketMessage {
  NewMessage(message: ClientChatMessage)
  MessageConfirmation(confirmation: ChatConfirmation)
  IsTyping(user: UserId)
  OnlineHasChanged(online: List(UserId))
}

pub fn to_json(socket_message: ServerToClientSocketMessage) -> Json {
  case socket_message {
    NewMessage(message:) ->
      json.object([
        #("type", json.string("new_message")),
        #("message", message |> shared_chat.chat_message_to_json),
      ])
    IsTyping(user:) ->
      json.object([
        #("type", json.string("is_typing")),
        #("user", user |> shared_user.user_id_to_json),
      ])
    OnlineHasChanged(online:) ->
      json.object([
        #("type", json.string("online_has_changed")),
        #("online", online |> json.array(shared_user.user_id_to_json)),
      ])
    MessageConfirmation(confirmation:) ->
      json.object([
        #("type", json.string("message_confirmation")),
        #(
          "confirmation",
          confirmation |> shared_chat_confirmation.chat_confirmation_to_json,
        ),
      ])
  }
}

pub fn decoder() -> Decoder(ServerToClientSocketMessage) {
  use variant <- decode.field("type", decode.string)

  case variant {
    "new_message" -> {
      use message <- decode.field("message", shared_chat.chat_message_decoder())
      message |> NewMessage(message: _) |> decode.success
    }
    "is_typing" -> {
      use user <- decode.field("user", shared_user.user_id_decoder())
      user |> IsTyping(user: _) |> decode.success
    }
    "online_has_changed" -> {
      use online <- decode.field(
        "online",
        shared_user.user_id_decoder() |> decode.list,
      )
      online |> OnlineHasChanged(online: _) |> decode.success
    }
    "message_confirmation" -> {
      use confirmation <- decode.field(
        "confirmation",
        shared_chat_confirmation.chat_confirmation_decoder(),
      )
      confirmation |> MessageConfirmation |> decode.success
    }
    _ -> decode.failure(IsTyping(UserId("")), "ServerToClientSocketMessage")
  }
}
