import app/domain/user.{type UserId, UserId}
import app/persist/pool.{type DbPool}
import app/persist/sql.{
  type ChatMessageDelivery, type SelectChatMessagesBySenderIdOrReceiverIdRow,
}
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import pog
import shared_chat.{type ChatMessage, type ClientChatMessage, ChatMessage}
import wisp.{type Request, type Response}
import youid/uuid.{type Uuid}

// ################################################################################
// Types
// ################################################################################

pub type ServerChatMessage =
  ChatMessage(UserId, ChatMessageDelivery)

// ################################################################################
// Mappings
// ################################################################################

fn message_from_rows(
  row: SelectChatMessagesBySenderIdOrReceiverIdRow,
) -> ServerChatMessage {
  ChatMessage(
    sender: row.sender_id |> UserId,
    receiver: row.receiver_id |> UserId,
    delivery: row.delivery,
    sent_time: row.created_at |> option.Some,
    text_content: row.text_content,
  )
}

fn to_shared_message(msg: ServerChatMessage) -> ClientChatMessage {
  ChatMessage(
    sender: msg.sender |> user.to_shared_user_id,
    receiver: msg.receiver |> user.to_shared_user_id,
    delivery: msg.delivery |> to_shared_chat_message_delivery,
    sent_time: msg.sent_time,
    text_content: msg.text_content,
  )
}

fn to_shared_chat_message_delivery(
  delivery: ChatMessageDelivery,
) -> shared_chat.ChatMessageDelivery {
  case delivery {
    sql.Sent -> shared_chat.Sent
    sql.Delivered -> shared_chat.Delivered
    sql.Read -> shared_chat.Read
  }
}

// ################################################################################
// Queries
// ################################################################################

pub fn get_chat_messages_for_user(
  db: DbPool,
  user_id: Uuid,
) -> Result(List(ChatMessage(UserId, ChatMessageDelivery)), pog.QueryError) {
  db
  |> pool.conn()
  |> sql.select_chat_messages_by_sender_id_or_receiver_id(user_id)
  |> result.map(fn(query_result) {
    list.map(query_result.rows, message_from_rows)
  })
}

// ################################################################################
// Endpoints
// ################################################################################

/// GET `/chats/:id` endpoint
pub fn chats(req: Request, db: DbPool, user_id: String) -> Response {
  use <- wisp.require_method(req, http.Get)

  {
    use user_id <- result.try(
      uuid.from_string(user_id) |> result.map_error(fn(_) { wisp.not_found() }),
    )

    use chat_messages: List(ChatMessage(UserId, ChatMessageDelivery)) <- result.try(
      get_chat_messages_for_user(db, user_id)
      |> result.map_error(fn(_) { wisp.internal_server_error() }),
    )

    let jsons =
      json.array(chat_messages, fn(msg) {
        msg |> to_shared_message |> shared_chat.chat_message_to_json
      })

    wisp.json_response(jsons |> json.to_string, 200) |> Ok
  }
  |> result.unwrap_both()
}
