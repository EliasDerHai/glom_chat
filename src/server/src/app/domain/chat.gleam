import app/domain/session
import app/domain/user.{type UserId, UserId}
import app/persist/pool.{type DbPool}
import app/persist/sql.{
  type ChatMessageDelivery, type SelectChatMessagesBySenderIdOrReceiverIdRow,
}
import app/util/query_result
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import pog
import shared_chat.{type ChatMessage, type ClientChatMessage, ChatMessage}
import shared_chat_conversation
import util/dict_extension
import wisp.{type Request, type Response}
import youid/uuid

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
  user_id: UserId,
) -> Result(List(ChatMessage(UserId, ChatMessageDelivery)), pog.QueryError) {
  db
  |> pool.conn()
  |> sql.select_chat_messages_by_sender_id_or_receiver_id(user_id.v)
  |> result.map(fn(query_result) {
    list.map(query_result.rows, message_from_rows)
  })
}

// ################################################################################
// Endpoints
// ################################################################################

/// GET `/chats/conversations` endpoint
pub fn chat_conversations(
  req: Request,
  db: DbPool,
  session: session.SessionEntity,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  {
    use messages: List(ChatMessage(UserId, ChatMessageDelivery)) <- result.try(
      get_chat_messages_for_user(db, session.user_id)
      |> query_result.map_query_result(),
    )

    let conversation_partners =
      messages
      |> list.flat_map(fn(item) { [item.receiver, item.sender] })
      |> set.from_list()
      |> set.filter(fn(item) { item != session.user_id })

    use conversation_partners <- result.try(
      db |> user.select_users_by_ids(conversation_partners),
    )

    shared_chat_conversation.ChatConversationDto(
      messages: messages |> list.map(to_shared_message),
      self: session.user_id |> user.to_shared_user_id,
      others: conversation_partners |> list.map(user.to_shared_user_mini),
    )
    |> shared_chat_conversation.chat_conversation_dto_to_json
    |> json.to_string
    |> wisp.json_response(200)
    |> Ok
  }
  |> result.unwrap_both()
}
