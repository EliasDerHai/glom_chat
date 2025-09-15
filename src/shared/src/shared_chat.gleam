import gleam/dynamic/decode
import gleam/float
import gleam/json.{type Json}
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import shared_user.{type UserId, UserId}

pub type ChatMessage(user_id) {
  ChatMessage(
    /// user_id
    sender: user_id,
    /// username
    receiver: user_id,
    delivery: ChatMessageDelivery,
    /// utc when server received (sent) message
    sent_time: Option(Timestamp),
    /// `\n` is splitted to allow delimiter agnostic newlines
    text_content: List(String),
  )
}

pub type ChatMessageDelivery {
  /// user is actively typing msg or switched tabs/conversations but hasn't sent msg yet
  Draft
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
    Draft -> json.string("draft")
    Sending -> json.string("sending")
    Sent -> json.string("sent")
    Delivered -> json.string("delivered")
    Read -> json.string("read")
  }
}

fn chat_message_delivery_decoder() -> decode.Decoder(ChatMessageDelivery) {
  use variant <- decode.then(decode.string)
  case variant {
    "draft" -> decode.success(Draft)
    "sending" -> decode.success(Sending)
    "sent" -> decode.success(Sent)
    "delivered" -> decode.success(Delivered)
    "read" -> decode.success(Read)
    _ -> decode.failure(Draft, "ChatMessageDelivery")
  }
}

pub fn chat_message_to_json(chat_message: ChatMessage(UserId)) -> Json {
  let ChatMessage(sender:, receiver:, delivery:, sent_time:, text_content:) =
    chat_message
  json.object([
    #("sender", json.string(sender.v)),
    #("receiver", json.string(receiver.v)),
    #("delivery", chat_message_delivery_to_json(delivery)),
    #("sent_time", case sent_time {
      option.None -> json.null()
      option.Some(value) ->
        value
        |> timestamp.to_unix_seconds
        |> float.round
        |> json.int
    }),
    #("text_content", json.array(text_content, json.string)),
  ])
}

pub fn chat_message_decoder() -> decode.Decoder(ChatMessage(UserId)) {
  use sender <- decode.field("sender", decode.string)
  use receiver <- decode.field("receiver", decode.string)
  use delivery <- decode.field("delivery", chat_message_delivery_decoder())
  use sent_time <- decode.field("sent_time", decode.int |> decode.optional)
  use text_content <- decode.field("text_content", decode.string |> decode.list)

  ChatMessage(
    sender: sender |> UserId,
    receiver: receiver |> UserId,
    delivery:,
    sent_time: sent_time |> option.map(timestamp.from_unix_seconds),
    text_content:,
  )
  |> decode.success
}
