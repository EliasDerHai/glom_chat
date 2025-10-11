import chat/shared_chat.{type ChatMessageDelivery}
import chat/shared_chat_id.{type ClientChatId}
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}

// ConfirmationKind  --------------------------------------------------

pub type ConfirmationKind {
  /// msg has been delivered to receiver
  Delivered
  /// msg has been opened and read by receiver
  Read
}

fn confirmation_kind_to_json(confirmation_kind: ConfirmationKind) -> Json {
  case confirmation_kind {
    Delivered -> json.string("delivered")
    Read -> json.string("read")
  }
}

fn confirmation_kind_decoder() -> Decoder(ConfirmationKind) {
  use variant <- decode.then(decode.string)
  case variant {
    "delivered" -> decode.success(Delivered)
    "read" -> decode.success(Read)
    _ -> decode.failure(Read, "ConfirmationKind")
  }
}

pub fn to_delivery(confirmation: ConfirmationKind) -> ChatMessageDelivery {
  case confirmation {
    Delivered -> shared_chat.Delivered
    Read -> shared_chat.Read
  }
}

// ChatConfirmation --------------------------------------------------

// TODO: rename to MessageConfirmation

pub type ChatConfirmation {
  ChatConfirmation(message_ids: List(ClientChatId), confirm: ConfirmationKind)
}

pub fn chat_confirmation_to_json(chat_confirmation: ChatConfirmation) -> Json {
  let ChatConfirmation(message_ids:, confirm:) = chat_confirmation
  json.object([
    #("message_ids", message_ids |> json.array(shared_chat_id.chat_id_to_json)),
    #("confirm", confirm |> confirmation_kind_to_json),
  ])
}

pub fn chat_confirmation_decoder() -> Decoder(ChatConfirmation) {
  use message_ids <- decode.field(
    "message_ids",
    shared_chat_id.chat_id_decoder() |> decode.list,
  )
  use confirm <- decode.field("confirm", confirmation_kind_decoder())
  decode.success(ChatConfirmation(message_ids:, confirm:))
}
