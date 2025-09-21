import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import lustre_websocket.{type WebSocket, type WebSocketEvent}
import rsvp.{type Error}
import shared_chat.{type ClientChatMessage}
import shared_chat_conversation.{type ChatConversationDto}
import shared_session.{type SessionDto}
import shared_user.{type UserId, type UserMiniDto}
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
    conversations: Dict(UserMiniDto(UserId), #(List(ClientChatMessage), String)),
  )
}

pub type NewConversation {
  NewConversation(suggestions: List(UserMiniDto(UserId)))
}

pub type SocketState {
  Pending(since: Timestamp)
  Established(WebSocket)
}

// MESSAGE ----------------------------------------------------------------------

pub type Msg {
  LoginSuccess(SessionDto)
  UserOnLogoutClick
  ApiOnLogoutResponse(Result(Nil, Error))
  ShowToast(Toast)
  RemoveToast(Int)
  WsWrapper(WebSocketEvent)
  CheckedAuth(Result(SessionDto, Error))
  NewConversationMsg(NewConversationMsg)
  UserOnSendSubmit
  ApiChatMessageFetchResponse(Result(ChatConversationDto, Error))
  ApiChatMessageSendResponse(Result(ClientChatMessage, Error))
}

pub type NewConversationMsg {
  UserModalOpen
  UserModalClose
  UserSearchInputChange(String)
  ApiSearchResponse(Result(List(UserMiniDto(UserId)), Error))
  UserConversationPartnerSelect(UserMiniDto(UserId))
}
