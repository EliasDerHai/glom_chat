import gleam/int
import shared_user

pub type BotId {
  BotId(v: Int)
}

pub fn v(id: BotId) {
  id.v
}

pub fn str(id: BotId) {
  "bot-" <> id.v |> int.to_string
}

const bot_pw = "123456"

pub fn username(id: BotId) {
  id |> str |> shared_user.Username
}

pub fn email(id: BotId) {
  id |> str <> "@bot.com"
}

pub fn pw() {
  bot_pw
}
