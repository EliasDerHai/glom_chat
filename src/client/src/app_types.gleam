import chat/shared_chat.{type ClientChatMessage}
import chat/shared_chat_confirmation.{type ChatConfirmation}
import chat/shared_chat_conversation.{type ChatConversationDto}
import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/set.{type Set}
import gleam/time/timestamp.{type Timestamp}
import lustre_websocket.{type WebSocket, type WebSocketEvent}
import rsvp.{type Error}
import shared_session.{type SessionDto}
import shared_user.{type UserId, type UserMiniDto, type Username}
import util/toast.{type Toast}

// MODEL -----------------------------------------------------------------------

/// overall model including all state
pub type Model {
  Model(app_state: AppState, global_state: GlobalState)
}

/// state of the app with business logic
pub type AppState {
  PreLogin
  LoggedIn(LoginState)
}

/// separate global state incl.
/// - toasts 
/// - configs (potentially)
/// shouldn't relate to business logic
pub type GlobalState {
  GlobalState(toasts: List(Toast))
}

pub type LoginState {
  LoginState(
    session: SessionDto,
    web_socket: SocketState,
    new_conversation: Option(NewConversation),
    selected_conversation: Option(UserMiniDto(UserId)),
    conversations: Dict(UserId, Conversation),
    conversations_filter: String,
    online: Set(UserId),
    typing: List(#(Int, UserId)),
  )
}

pub type Conversation {
  Conversation(
    messages: List(ClientChatMessage),
    conversation_partner: Username,
    draft_message_text: String,
  )
}

pub type NewConversation {
  NewConversation(suggestions: List(UserMiniDto(UserId)), search: String)
}

pub type SocketState {
  Pending(since: Timestamp)
  Established(socket: WebSocket)
}

// MESSAGE ----------------------------------------------------------------------

pub type Msg {
  LoginSuccess(SessionDto)
  UserOnLogoutClick
  ApiOnLogoutResponse(Result(Nil, Error))
  ShowToast(Toast)
  RemoveToast(Int)
  WsWrapper(WebSocketEvent)
  IsTypingExpired(Int)
  CheckedAuth(Result(SessionDto, Error))
  NewConversationMsg(NewConversationMsg)
  UserOnConversationFilter(String)
  //  no debounce
  UserOnDraftTextChange(String)
  //  debounced
  UserOnTyping
  UserOnSendSubmit
  ApiChatMessageFetchResponse(Result(ChatConversationDto, Error))
  ApiChatMessageSendResponse(Result(ClientChatMessage, Error))
  ApiChatMessageConfirmationResponse(Result(ChatConfirmation, Error))
}

pub type NewConversationMsg {
  UserModalOpen
  UserModalClose
  UserSearchInputChange(String)
  ApiSearchResponse(Result(List(UserMiniDto(UserId)), Error))
  UserConversationPartnerSelect(UserMiniDto(UserId))
}
