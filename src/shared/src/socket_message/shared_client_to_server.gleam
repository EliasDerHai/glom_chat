import gleam/dynamic/decode
import gleam/json.{type Json}
import shared_user.{type UserId}

pub type ClientToServerSocketMessage {
  IsTyping(typer: UserId, receiver: UserId)
}

pub fn to_json(message: ClientToServerSocketMessage) -> Json {
  let IsTyping(typer:, receiver:) = message
  json.object([
    #("typer", typer |> shared_user.user_id_to_json),
    #("receiver", receiver |> shared_user.user_id_to_json),
  ])
}

pub fn decoder() -> decode.Decoder(ClientToServerSocketMessage) {
  use typer <- decode.field("typer", shared_user.user_id_decoder())
  use receiver <- decode.field("receiver", shared_user.user_id_decoder())
  decode.success(IsTyping(typer:, receiver:))
}
