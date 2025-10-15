import gleam/int
import ids/csrf_token.{type CsrfToken}
import ids/encrypted_session_id.{type EncryptedSessionId}
import shared_session.{type SessionDto}
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

pub type Bot {
  Bot(
    id: BotId,
    session_id: EncryptedSessionId,
    csrf_token: CsrfToken,
    session: SessionDto,
  )
}
