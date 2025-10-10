import chat/shared_chat_id.{type ClientChatId, ChatId}
import gleam/dynamic/decode.{type Decoder}
import gleam/float
import gleam/json.{type Json}
import gleam/time/timestamp.{type Timestamp}
import shared_user.{type UserId, UserId}

pub type ClientChatMessage =
  ChatMessage(ClientChatId, UserId, ChatMessageDelivery)

pub type ChatMessage(chat_id, user_id, chat_message_delivery) {
  ChatMessage(
    id: chat_id,
    /// user_id
    sender: user_id,
    /// username
    receiver: user_id,
    delivery: chat_message_delivery,
    /// utc when server received (sent) message
    sent_time: Timestamp,
    /// `\n` is splitted to allow delimiter agnostic newlines
    text_content: List(String),
  )
}

pub type ChatMessageDelivery {
  /// msg is being sent server hasn't received
  Sending
  /// msg has been sent to server
  Sent
  /// msg has been delivered to receiver
  Delivered
  /// msg has been opened and read by receiver
  Read
}

fn chat_message_delivery_to_json(
  chat_message_delivery: ChatMessageDelivery,
) -> Json {
  case chat_message_delivery {
    Sending -> json.string("sending")
    Sent -> json.string("sent")
    Delivered -> json.string("delivered")
    Read -> json.string("read")
  }
}

fn chat_message_delivery_decoder() -> Decoder(ChatMessageDelivery) {
  use variant <- decode.then(decode.string)
  case variant {
    "sending" -> decode.success(Sending)
    "sent" -> decode.success(Sent)
    "delivered" -> decode.success(Delivered)
    "read" -> decode.success(Read)
    _ -> decode.failure(Sent, "ChatMessageDelivery")
  }
}

pub fn chat_message_to_json(chat_message: ClientChatMessage) -> Json {
  let ChatMessage(id:, sender:, receiver:, delivery:, sent_time:, text_content:) =
    chat_message
  json.object([
    #("id", json.string(id.v)),
    #("sender", json.string(sender.v)),
    #("receiver", json.string(receiver.v)),
    #("delivery", chat_message_delivery_to_json(delivery)),
    #(
      "sent_time",
      sent_time
        |> timestamp.to_unix_seconds
        |> float.round
        |> json.int,
    ),
    #("text_content", json.array(text_content, json.string)),
  ])
}

pub fn chat_message_decoder() -> Decoder(ClientChatMessage) {
  use id <- decode.field("id", decode.string)
  use sender <- decode.field("sender", decode.string)
  use receiver <- decode.field("receiver", decode.string)
  use delivery <- decode.field("delivery", chat_message_delivery_decoder())
  use sent_time <- decode.field("sent_time", decode.int)
  use text_content <- decode.field("text_content", decode.string |> decode.list)

  ChatMessage(
    id: id |> ChatId,
    sender: sender |> UserId,
    receiver: receiver |> UserId,
    delivery:,
    sent_time: sent_time |> timestamp.from_unix_seconds,
    text_content:,
  )
  |> decode.success
}
