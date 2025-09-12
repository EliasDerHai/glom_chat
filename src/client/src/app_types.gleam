import gleam/option
import gleam/time/timestamp
import lustre_websocket.{type WebSocket} as ws
import rsvp
import shared_session.{type SessionDto}
import shared_user.{type Username}
import util/form.{type FormField}
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
    user: SessionDto,
    web_socket: SocketState,
    new_conversation: option.Option(NewConversation),
  )
}

pub type NewConversation {
  NewConversation(field: FormField(Nil), suggestions: List(Username))
}

pub type SocketState {
  Pending(since: timestamp.Timestamp)
  Established(WebSocket)
}

// MESSAGE ----------------------------------------------------------------------

pub type Msg {
  LoginSuccess(SessionDto)
  ShowToast(Toast)
  RemoveToast(Int)
  WsWrapper(ws.WebSocketEvent)
  CheckedAuth(Result(SessionDto, rsvp.Error))
  OpenNewConversation
  CloseNewConversation
}
