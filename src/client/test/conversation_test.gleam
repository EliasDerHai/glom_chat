import app_types.{type Conversation, Conversation}
import conversation
import gleam/dict
import gleam/list
import gleam/option.{Some}
import gleam/time/timestamp
import gleeunit/should
import shared_chat.{type ClientChatMessage, ChatMessage, Sent}
import shared_user.{type UserId, UserId, Username}

fn msg(unix_secs: Int) -> ClientChatMessage {
  ChatMessage(
    sender: UserId("sender"),
    receiver: UserId("receiver"),
    delivery: Sent,
    sent_time: Some(timestamp.from_unix_seconds(unix_secs)),
    text_content: ["msg"],
  )
}

fn conv(user: String, times: List(Int)) -> #(UserId, Conversation) {
  #(
    UserId(user),
    Conversation(
      messages: times |> list.map(fn(t) { msg(t) }),
      conversation_partner: Username(user),
      draft_message_text: "",
    ),
  )
}

pub fn sort_conversations_single_test() {
  let conversations = dict.from_list([conv("amy", [1000])])

  let result = conversation.sort_conversations(conversations)

  result |> should.equal([conv("amy", [1000])])
}

pub fn sort_conversations_newest_first_test() {
  let conversations =
    dict.from_list([
      conv("amy", [1000]),
      conv("becky", [2000]),
    ])

  let result = conversation.sort_conversations(conversations)

  result
  |> should.equal([
    conv("becky", [2000]),
    conv("amy", [1000]),
  ])
}

pub fn sort_conversations_uses_latest_message_test() {
  let conversations =
    dict.from_list([
      conv("amy", [500, 1500]),
      conv("becky", [1000]),
    ])

  let result = conversation.sort_conversations(conversations)

  result
  |> should.equal([
    conv("amy", [500, 1500]),
    conv("becky", [1000]),
  ])
}
