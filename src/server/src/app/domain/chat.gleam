import app/domain/session
import app/domain/user.{type UserId, UserId}
import app/persist/pool.{type DbPool}
import app/persist/sql.{
  type ChatMessageDelivery, type SelectChatMessagesBySenderIdOrReceiverIdRow,
}
import app/registry.{type SocketRegistry}
import app/util/query_result
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/result
import gleam/set
import gleam/time/calendar
import gleam/time/timestamp
import pog
import shared_chat.{type ChatMessage, type ClientChatMessage, ChatMessage}
import shared_chat_conversation
import shared_socket_message
import util/result_extension
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

fn message_from_shared_message(
  msg: ClientChatMessage,
) -> Result(ServerChatMessage, Nil) {
  use sender <- result.try(msg.sender |> user.from_shared_user_id)
  use receiver <- result.try(msg.receiver |> user.from_shared_user_id)

  ChatMessage(
    sender:,
    receiver:,
    delivery: case msg.delivery {
      shared_chat.Delivered -> sql.Delivered
      shared_chat.Read -> sql.Read
      shared_chat.Sent -> sql.Sent
      _ -> sql.Sent
    },
    sent_time: msg.sent_time,
    text_content: msg.text_content,
  )
  |> Ok
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

pub fn insert_chat_message(
  db: DbPool,
  msg: ChatMessage(UserId, ChatMessageDelivery),
) -> Result(pog.Returned(Nil), pog.QueryError) {
  db
  |> pool.conn
  |> sql.insert_chat_message(
    uuid.v7(),
    msg.sender.v,
    msg.receiver.v,
    msg.delivery,
    msg.text_content,
  )
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
  |> result_extension.unwrap_both()
}

pub fn post_chat_message(
  req: Request,
  db: DbPool,
  registry: SocketRegistry,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  {
    use msg <- result.try(
      json
      |> decode.run(shared_chat.chat_message_decoder())
      |> result.map_error(fn(_) {
        wisp.bad_request("can't decode chat_message")
      })
      |> result.map(fn(r) {
        message_from_shared_message(r)
        |> result.map_error(fn(_) { wisp.bad_request("can't decode user_ids") })
      })
      |> result.flatten,
    )

    let local_now =
      timestamp.system_time() |> timestamp.add(calendar.local_offset())

    let msg =
      ChatMessage(..msg, delivery: sql.Sent, sent_time: option.Some(local_now))

    use _ <- result.try(
      insert_chat_message(db, msg)
      |> query_result.map_query_result(),
    )

    actor.send(
      registry,
      registry.OnNotifyClient(
        msg.receiver,
        shared_socket_message.NewMessage(msg |> to_shared_message),
      ),
    )

    msg
    |> to_shared_message
    |> shared_chat.chat_message_to_json
    |> json.to_string
    |> wisp.json_response(201)
    |> Ok
  }
  |> result_extension.unwrap_both()
}
