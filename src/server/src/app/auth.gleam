import app/domain/session.{type SessionEntity}
import gleam/crypto
import youid/uuid

pub fn generate_csrf_token(session: SessionEntity) -> BitArray {
  let payload = uuid.to_string(session.id) <> ":" <> session.csrf_secret
  crypto.hash(crypto.Sha256, <<payload:utf8>>)
}
