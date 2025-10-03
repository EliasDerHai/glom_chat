import app_types.{type Conversation}
import gleam/dict
import gleam/list
import gleam/option.{type Option}
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
  |> sort_messages
  |> list.last
  |> result.map(fn(msg) { msg.sent_time |> unwrap_time_option })
  |> unwrap_time_result
}

pub fn sort_messages(messages: List(ClientChatMessage)) {
  messages
  |> list.sort(fn(left, right) {
    timestamp.compare(
      left.sent_time |> unwrap_time_option,
      right.sent_time |> unwrap_time_option,
    )
  })
}

fn unwrap_time_option(time: Option(Timestamp)) -> Timestamp {
  time |> option.unwrap(timestamp.from_unix_seconds(0))
}

fn unwrap_time_result(time: Result(Timestamp, _)) -> Timestamp {
  time |> result.unwrap(timestamp.from_unix_seconds(0))
}
