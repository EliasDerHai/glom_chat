import app/domain/session.{type SessionEntity}
import app/domain/user.{type UserId, UserId}
import app/persist/pool.{type DbPool}
import app/persist/sql.{
  type ChatMessageDelivery, type SelectChatMessagesBySenderIdOrReceiverIdRow,
}
import app/registry.{type SocketRegistry, OnNotifyClient}
import app/util/query_result
import chat/shared_chat.{type ChatMessage, type ClientChatMessage, ChatMessage}
import chat/shared_chat_confirmation.{type ChatConfirmation, ChatConfirmation}
import chat/shared_chat_conversation
import chat/shared_chat_creation_dto
import chat/shared_chat_id.{type ClientChatId, ChatId}
import gleam/dict
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/otp/actor
import gleam/result
import gleam/set
import gleam/time/timestamp
import pog.{type QueryError}
import socket_message/shared_server_to_client.{MessageConfirmation}
import util/result_extension
import wisp.{type Request, type Response}
import youid/uuid

// ################################################################################
// Types
// ################################################################################

type ChatId =
  shared_chat_id.ChatId(uuid.Uuid)

pub type ServerChatMessage =
  ChatMessage(ChatId, UserId, ChatMessageDelivery)

// ################################################################################
// Mappings
// ################################################################################

fn message_from_rows(
  row: SelectChatMessagesBySenderIdOrReceiverIdRow,
) -> ServerChatMessage {
  ChatMessage(
    id: row.id |> ChatId,
    sender: row.sender_id |> UserId,
    receiver: row.receiver_id |> UserId,
    delivery: row.delivery,
    sent_time: row.created_at,
    text_content: row.text_content,
  )
}

fn to_sql_delivery(
  delivery: shared_chat.ChatMessageDelivery,
) -> sql.ChatMessageDelivery {
  case delivery {
    shared_chat.Delivered -> sql.Delivered
    shared_chat.Read -> sql.Read
    shared_chat.Sent -> sql.Sent
    shared_chat.Sending -> sql.Sent
  }
}

// TODO: cleanup

//fn message_from_shared_message(
//  msg: ClientChatMessage,
//) -> Result(ServerChatMessage, Nil) {
//  use id <- result.try(msg.id |> from_shared_chat_id)
//  use sender <- result.try(msg.sender |> user.from_shared_user_id)
//  use receiver <- result.try(msg.receiver |> user.from_shared_user_id)
//
//  ChatMessage(
//    id:,
//    sender:,
//    receiver:,
//    delivery: case msg.delivery {
//      shared_chat.Delivered -> sql.Delivered
//      shared_chat.Read -> sql.Read
//      shared_chat.Sent -> sql.Sent
//      _ -> sql.Sent
//    },
//    sent_time: msg.sent_time,
//    text_content: msg.text_content,
//  )
//  |> Ok
//}

fn to_shared_message(msg: ServerChatMessage) -> ClientChatMessage {
  ChatMessage(
    id: msg.id |> to_shared_chat_id,
    sender: msg.sender |> user.to_shared_user_id,
    receiver: msg.receiver |> user.to_shared_user_id,
    delivery: msg.delivery |> to_shared_chat_message_delivery,
    sent_time: msg.sent_time,
    text_content: msg.text_content,
  )
}

fn to_shared_chat_id(chat_id: ChatId) -> ClientChatId {
  chat_id.v |> uuid.to_string |> shared_chat_id.ChatId
}

fn from_shared_chat_id(chat_id: ClientChatId) -> Result(ChatId, Nil) {
  chat_id.v
  |> uuid.from_string
  |> result.map(fn(id) { id |> shared_chat_id.ChatId })
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

fn get_chat_messages_for_user(
  db: DbPool,
  user_id: UserId,
) -> Result(List(ServerChatMessage), QueryError) {
  db
  |> pool.conn()
  |> sql.select_chat_messages_by_sender_id_or_receiver_id(user_id.v)
  |> result.map(fn(query_result) {
    list.map(query_result.rows, message_from_rows)
  })
}

fn insert_chat_message(
  db: DbPool,
  msg: ServerChatMessage,
) -> Result(pog.Returned(Nil), QueryError) {
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
  session: SessionEntity,
) -> Response {
  use <- wisp.require_method(req, http.Get)

  {
    use messages: List(ServerChatMessage) <- result.try(
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
  session: SessionEntity,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  {
    use msg <- result.try(
      json
      |> decode.run(shared_chat_creation_dto.decoder())
      |> result.map_error(fn(_) {
        wisp.bad_request("can't decode chat_message")
      })
      |> result.map(fn(r) {
        let shared_chat_creation_dto.ChatMessageCreationDto(
          receiver:,
          text_content:,
        ) = r

        use receiver <- result.try(
          receiver
          |> user.from_shared_user_id
          |> result.map_error(fn(_) {
            wisp.bad_request("can't decode receiver's user_id")
          }),
        )

        ChatMessage(
          id: shared_chat_id.ChatId(uuid.v7()),
          receiver:,
          sender: session.user_id,
          delivery: sql.Sent,
          sent_time: timestamp.system_time(),
          text_content:,
        )
        |> Ok
      })
      |> result.flatten,
    )

    use _ <- result.try(
      insert_chat_message(db, msg)
      |> query_result.map_query_result(),
    )

    actor.send(
      registry,
      OnNotifyClient(
        msg.receiver,
        shared_server_to_client.NewMessage(msg |> to_shared_message),
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

pub fn post_chat_confirmations(
  req: Request,
  db: DbPool,
  registry: SocketRegistry,
  session: SessionEntity,
) -> Response {
  use <- wisp.require_method(req, http.Post)
  use json <- wisp.require_json(req)

  {
    use dto <- result.try(
      json
      |> decode.run(shared_chat_confirmation.chat_confirmation_decoder())
      |> result.map_error(fn(_) {
        wisp.bad_request("can't decode chat_message")
      }),
    )

    use _ <- result.try(
      confirm_messages(db, dto, registry, session)
      |> query_result.map_query_result,
    )

    wisp.ok()
    |> wisp.json_body(
      dto
      // kind of dumb that we have to do a full serialization roundtrip just bc of the type 
      |> shared_chat_confirmation.chat_confirmation_to_json
      |> json.to_string,
    )
    |> Ok
  }
  |> result_extension.unwrap_both()
}

pub fn confirm_messages(
  db: DbPool,
  dto: ChatConfirmation,
  registry: SocketRegistry,
  session: SessionEntity,
) -> Result(ChatConfirmation, QueryError) {
  let delivery =
    dto.confirm
    |> shared_chat_confirmation.to_delivery
    |> to_sql_delivery

  let message_ids =
    dto.message_ids
    |> list.filter_map(from_shared_chat_id)
    |> list.map(fn(id) { id.v })

  use r <- result.try(
    db
    |> pool.conn
    |> sql.update_chat_messages_delivery(
      delivery,
      message_ids,
      session.user_id.v,
    ),
  )

  r.rows
  |> list.group(fn(row) { row.sender_id |> UserId })
  |> dict.map_values(fn(_, rows) {
    rows |> list.map(fn(row) { row.id |> ChatId |> to_shared_chat_id })
  })
  |> dict.each(fn(user_id, chat_ids) {
    registry
    |> actor.send(OnNotifyClient(
      user_id,
      MessageConfirmation(ChatConfirmation(chat_ids, dto.confirm)),
    ))
  })

  Ok(dto)
}
