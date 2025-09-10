import endpoints
import gleam/io
import gleam/list
import gleam/option.{type Option, None}
import gleam/string
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre_websocket.{type WebSocket} as ws
import pre_login
import shared_user
import util/time_util
import util/toast.{type Toast}

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)

  let assert Ok(_) = pre_login.register()
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}

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
  LoginState(user: shared_user.UserDto, web_socket: Option(WebSocket))
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  let model = Model(PreLogin, GlobalState([]))

  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  LoginSuccess(shared_user.UserDto)
  ShowToast(Toast)
  RemoveToast(Int)
  WsWrapper(ws.WebSocketEvent)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model.app_state, msg {
    // ### TOASTS ###
    _, ShowToast(toast_msg) -> show_toast(model, toast_msg)
    _, RemoveToast(toast_id) -> remove_toast(model, toast_id)

    // ### LOGIN SUCCESS ###
    PreLogin, LoginSuccess(user_dto) -> {
      let ws_connect_effect = ws.init(endpoints.socket_address(), WsWrapper)
      #(
        Model(LoggedIn(LoginState(user_dto, None)), model.global_state),
        ws_connect_effect,
      )
    }

    LoggedIn(_), LoginSuccess(_) -> {
      // User already logged in, ignore duplicate login
      #(model, effect.none())
    }

    // ### WEBSOCKET ###
    _, WsWrapper(socket_event) -> {
      case socket_event {
        ws.InvalidUrl -> panic as "invalid socket url"
        ws.OnOpen(socket) -> {
          io.println("WebSocket connected successfully")
          case model.app_state {
            LoggedIn(login_state) -> {
              let updated_login_state =
                LoginState(..login_state, web_socket: option.Some(socket))
              #(
                Model(LoggedIn(updated_login_state), model.global_state),
                effect.none(),
              )
            }
            _ -> #(model, effect.none())
          }
        }
        ws.OnBinaryMessage(_) -> panic as "received unexpected binary message"
        ws.OnTextMessage(message) -> {
          io.println("Received WebSocket message: " <> message)
          // TODO: Parse and handle different message types
          #(model, effect.none())
        }
        ws.OnClose(close_reason) -> {
          io.println("WebSocket closed: " <> string.inspect(close_reason))
          case model.app_state {
            LoggedIn(login_state) -> {
              let updated_login_state =
                LoginState(..login_state, web_socket: option.None)
              #(
                Model(LoggedIn(updated_login_state), model.global_state),
                effect.none(),
              )
            }
            _ -> #(model, effect.none())
          }
        }
      }
    }
  }
}

fn show_toast(model: Model, toast_msg: Toast) -> #(Model, Effect(Msg)) {
  let new_toasts = toast.add_toast(model.global_state.toasts, toast_msg)
  let new_global_state = GlobalState(new_toasts)
  let timeout_effect =
    effect.from(fn(dispatch) {
      time_util.set_timeout(
        fn() { dispatch(RemoveToast(toast_msg.id)) },
        toast_msg.duration,
      )
    })
  #(Model(model.app_state, new_global_state), timeout_effect)
}

fn remove_toast(model: Model, toast_id: Int) -> #(Model, Effect(Msg)) {
  let new_toasts = toast.remove_toast_by_id(model.global_state.toasts, toast_id)
  let new_global_state = GlobalState(new_toasts)
  #(Model(model.app_state, new_global_state), effect.none())
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  // deriving socket-conn-lost info directly from model
  let toasts = case model.app_state {
    LoggedIn(LoginState(_, None)) ->
      toast.add_toast(
        model.global_state.toasts,
        toast.create_error_toast("Socket connection lost - reconnecting..."),
      )
    _ ->
      list.filter(model.global_state.toasts, fn(toast_msg) {
        !string.starts_with(toast_msg.content, "Socket connection lost")
      })
  }

  html.div([], [
    // Main content based on app state
    case model.app_state {
      LoggedIn(LoginState(shared_user.UserDto(_, username, ..), ..)) ->
        html.div([], [html.text("Welcome " <> username <> "!")])

      PreLogin ->
        pre_login.element([
          pre_login.on_login_success(LoginSuccess),
          pre_login.on_show_toast(ShowToast),
        ])
    },

    // Toast notifications overlay
    toast.view_toasts(toasts),
  ])
}
