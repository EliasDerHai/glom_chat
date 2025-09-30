import app_types.{type Conversation}
import gleam/dict
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import shared_chat.{type ClientChatMessage}
import shared_user.{type UserId}

// latest first
pub fn sort_conversations(
  conversations: dict.Dict(UserId, Conversation),
) -> List(#(UserId, Conversation)) {
  conversations
  |> dict.to_list
  |> list.sort(fn(left, right) {
    let left = left.1
    let right = right.1

    order.break_tie(
      timestamp.compare(
        latest_message_time(left.messages),
        latest_message_time(right.messages),
      ),
      string.compare(left.conversation_partner.v, right.conversation_partner.v),
    )
  })
  // newest goes to top ^^^
  |> list.reverse
}

fn latest_message_time(messages: List(ClientChatMessage)) -> Timestamp {
  messages
  |> list.sort(fn(left, right) {
    timestamp.compare(
      left.sent_time |> option.unwrap(timestamp.from_unix_seconds(0)),
      right.sent_time |> option.unwrap(timestamp.from_unix_seconds(0)),
    )
  })
  |> list.last
  |> result.map(fn(msg) {
    option.unwrap(msg.sent_time, timestamp.from_unix_seconds(0))
  })
  |> result.unwrap(timestamp.from_unix_seconds(0))
}
