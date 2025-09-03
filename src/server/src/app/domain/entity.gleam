import gleam/time/timestamp
import youid/uuid.{type Uuid}

pub type SessionEntity {
  SessionEntity(
    id: Uuid,
    user_id: Uuid,
    expires_at: timestamp.Timestamp,
    csrf_secret: String,
  )
}

pub type UserEntity {
  UserEntity(id: Uuid, username: String, email: String, email_verified: Bool)
}
