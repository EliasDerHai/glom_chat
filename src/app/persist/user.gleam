import app/sql
import gluid
import pog
import squirrel

pub fn persist_user(conn: pog.Connection, user_name: String, email: String) {
  let user_id = gluid.guidv4()
  // TODO: impl
  // sql.insert_user(conn, user_id, user_name, email, false)
}
