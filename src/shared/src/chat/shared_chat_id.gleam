import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}

pub type ClientChatId =
  ChatId(String)

// Uuid on server
pub type ChatId(inner) {
  ChatId(v: inner)
}

pub fn chat_id_to_json(chat_id: ClientChatId) -> Json {
  chat_id.v |> json.string
}

pub fn chat_id_decoder() -> Decoder(ClientChatId) {
  use v <- decode.then(decode.string)
  decode.success(ChatId(v:))
}
