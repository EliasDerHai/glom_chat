import app/persist/pool.{type DbPool}
import app/persist/sql
import gleam/dynamic/decode
import gleam/http.{Delete, Get}
import gleam/json
import gleam/list
import gleam/result
import pog
import shared_user.{type Username, Username}
import wisp.{type Request, type Response}
import youid/uuid.{type Uuid}

/// GET `/chats/:id` endpoint
pub fn chats(req: Request, db: DbPool, user_id: String) -> Response {
  use <- wisp.require_method(req, http.Get)

  {
    use user_id <- result.try(
      uuid.from_string(user_id) |> result.map_error(fn(_) { wisp.not_found() }),
    )

    use chat_messages <- result.try(
      db
      |> pool.conn()
      |> sql.select_chat_messages_by_sender_id_or_receiver_id(user_id)
      |> result.map_error(fn(_) { wisp.internal_server_error() }),
    )

    wisp.json_response("", 200) |> Ok
  }
  |> result.unwrap_both()
}
