import app/domain/entity.{type SessionEntity}
import gleam/bit_array
import gleam/crypto
import youid/uuid

// ################################################################################
// CSRF Protection
// ################################################################################

pub type CsrfCheck {
  Passed
  Failed
}

pub fn verify_csrf_token(session: SessionEntity, token: String) -> CsrfCheck {
  let expected_token = generate_csrf_token(session)

  case bit_array.base64_url_decode(token) {
    Error(_) -> Failed
    Ok(token) ->
      case crypto.secure_compare(token, expected_token) {
        False -> Failed
        True -> Passed
      }
  }
}

pub fn generate_csrf_token(session: SessionEntity) -> BitArray {
  let payload = uuid.to_string(session.id) <> ":" <> session.csrf_secret
  crypto.hash(crypto.Sha256, <<payload:utf8>>)
}
