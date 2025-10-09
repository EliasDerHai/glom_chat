import chat/shared_chat_confirmation.{type ChatConfirmation}
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import shared_user.{type UserId, UserId}

pub type ClientToServerSocketMessage {
  IsTyping(typer: UserId, receiver: UserId)
  MessageConfirmation(confirmation: ChatConfirmation)
}

pub fn to_json(message: ClientToServerSocketMessage) -> Json {
  case message {
    IsTyping(typer:, receiver:) ->
      json.object([
        #("type", "is_typing" |> json.string),
        #("typer", typer |> shared_user.user_id_to_json),
        #("receiver", receiver |> shared_user.user_id_to_json),
      ])
    MessageConfirmation(confirmation:) ->
      json.object([
        #("type", "message_confirmation" |> json.string),
        #(
          "confirmation",
          confirmation |> shared_chat_confirmation.chat_confirmation_to_json,
        ),
      ])
  }
}

pub fn decoder() -> Decoder(ClientToServerSocketMessage) {
  use variant <- decode.field("type", decode.string)
  case variant {
    "is_typing" -> {
      use typer <- decode.field("typer", shared_user.user_id_decoder())
      use receiver <- decode.field("receiver", shared_user.user_id_decoder())
      decode.success(IsTyping(typer:, receiver:))
    }
    "message_confirmation" -> {
      use confirmation <- decode.field(
        "confirmation",
        shared_chat_confirmation.chat_confirmation_decoder(),
      )
      decode.success(MessageConfirmation(confirmation:))
    }
    _ ->
      decode.failure(
        IsTyping("" |> UserId, "" |> UserId),
        "ClientToServerSocketMessage",
      )
  }
}
