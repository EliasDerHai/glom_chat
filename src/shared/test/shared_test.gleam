import gleam/io
import gleam/json
import gleam/option
import gleam/time/timestamp
import gleeunit
import shared_chat.{ChatMessage}
import shared_user.{UserDto, UserId}

pub fn main() -> Nil {
  gleeunit.main()
}

// this compare circumvents a treesitter issue in my setup 
// https://github.com/gleam-lang/tree-sitter-gleam/issues/121#issuecomment-3259598900
pub fn assert_equal(expected: a, actual: a) -> Nil {
  case expected == actual {
    False -> {
      io.println("Expected:")
      echo expected
      io.println("Actual:")
      echo actual
      panic as "Don't equal"
    }
    True -> Nil
  }
}

pub fn user_json_roundtrip_test() {
  // arrange 
  let input =
    UserDto(
      "9c5b94b1-35ad-49bb-b118-8e8fc24abf80" |> shared_user.UserId,
      "John" |> shared_user.Username,
      "john.boy@gleamer.com",
      False,
    )

  // act serialize
  let actual = input |> shared_user.to_json()

  // assert serialize
  let expected =
    json.object([
      #("id", json.string("9c5b94b1-35ad-49bb-b118-8e8fc24abf80")),
      #("username", json.string("John")),
      #("email", json.string("john.boy@gleamer.com")),
      #("email_verified", json.bool(False)),
    ])
  assert_equal(expected, actual)

  // act deserialize
  let json_text = json.to_string(actual)
  let assert Ok(actual) =
    json.parse(from: json_text, using: shared_user.decode_user_dto())

  // assert deserialize
  assert_equal(input, actual)
}

pub fn chat_message_json_roundtrip_test() {
  // arrange
  let input =
    ChatMessage(
      sender: "9c5b94b1-35ad-49bb-b118-8e8fc24abf80" |> UserId,
      receiver: "7d4a83c2-26bd-48aa-a007-9f9ec35bcf91" |> UserId,
      delivery: shared_chat.Sent,
      sent_time: option.Some(timestamp.from_unix_seconds(1_692_859_999)),
      text_content: ["Hello", "How are you?"],
    )

  // act serialize
  let actual = input |> shared_chat.chat_message_to_json()

  // assert serialize
  let expected =
    json.object([
      #("sender", json.string("9c5b94b1-35ad-49bb-b118-8e8fc24abf80")),
      #("receiver", json.string("7d4a83c2-26bd-48aa-a007-9f9ec35bcf91")),
      #("delivery", json.string("sent")),
      #("sent_time", json.int(1_692_859_999)),
      #("text_content", json.array(["Hello", "How are you?"], json.string)),
    ])
  assert_equal(expected, actual)

  // act deserialize
  let json_text = json.to_string(actual)
  let assert Ok(actual) =
    json.parse(from: json_text, using: shared_chat.chat_message_decoder())

  // assert deserialize
  assert_equal(input, actual)
}

pub fn chat_message_json_roundtrip_with_null_sent_time_test() {
  // arrange - test with None sent_time
  let input =
    ChatMessage(
      sender: "sender-id" |> UserId,
      receiver: "receiver-id" |> UserId,
      delivery: shared_chat.Draft,
      sent_time: option.None,
      text_content: ["Draft message"],
    )

  // act serialize
  let actual = input |> shared_chat.chat_message_to_json()

  // assert serialize
  let expected =
    json.object([
      #("sender", json.string("sender-id")),
      #("receiver", json.string("receiver-id")),
      #("delivery", json.string("draft")),
      #("sent_time", json.null()),
      #("text_content", json.array(["Draft message"], json.string)),
    ])
  assert_equal(expected, actual)

  // act deserialize
  let json_text = json.to_string(actual)
  let assert Ok(actual) =
    json.parse(from: json_text, using: shared_chat.chat_message_decoder())

  // assert deserialize
  assert_equal(input, actual)
}
