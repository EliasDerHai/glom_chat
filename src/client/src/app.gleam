// IMPORTS ---------------------------------------------------------------------

import endpoints
import gleam/io
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre_websocket as ws
import pre_login.{type PreLoginMsg}
import shared_user
import util/time_util
import util/toast.{type Toast}

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// MODEL -----------------------------------------------------------------------

/// overall model including all state
pub type Model {
  Model(app_state: AppState, global_state: GlobalState)
}

/// state of the app/route with business logic
pub type AppState {
  PreLogin(pre_login.PreLoginState)
  LoggedIn(shared_user.UserDto)
}

/// separate global state incl.
/// - toasts 
/// - configs (potentially)
/// shouldn't relate to business logic
pub type GlobalState {
  GlobalState(toasts: List(Toast))
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  let model = Model(PreLogin(pre_login.init()), GlobalState([]))

  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  PreLoginMsg(PreLoginMsg)
  ShowToast(Toast)
  RemoveToast(Int)
  WsWrapper(ws.WebSocketEvent)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model.app_state, msg {
    // ### TOASTS ###
    _, PreLoginMsg(pre_login.ShowToast(toast_msg)) | _, ShowToast(toast_msg) ->
      show_toast(model, toast_msg)
    _, RemoveToast(toast_id) -> remove_toast(model, toast_id)

    // ### APP ###
    PreLogin(pre_login_model), PreLoginMsg(msg) -> {
      let #(pre_login_model, pre_login_effect) =
        pre_login.update(pre_login_model, msg)

      case msg {
        pre_login.ApiRespondLoginRequest(Ok(user_dto)) -> {
          let ws_connect_effect = ws.init(endpoints.socket_address(), WsWrapper)

          #(
            Model(LoggedIn(user_dto), model.global_state),
            effect.batch([
              effect.map(pre_login_effect, fn(msg) { PreLoginMsg(msg) }),
              ws_connect_effect,
            ]),
          )
        }

        _ -> #(
          Model(PreLogin(pre_login_model), model.global_state),
          effect.map(pre_login_effect, fn(msg) { PreLoginMsg(msg) }),
        )
      }
    }

    LoggedIn(user_dto), PreLoginMsg(msg) -> {
      echo #(user_dto, msg)
      panic as "Unexpected combination: PreLoginMsg while LoggedIn"
    }

    // ### WEBSOCKET ###
    _, WsWrapper(socket_event) -> {
      case socket_event {
        ws.InvalidUrl -> panic as "invalid socket url"
        ws.OnOpen(_) -> {
          io.println("WebSocket connected successfully")
          #(model, effect.none())
        }
        ws.OnBinaryMessage(_) -> panic as "received unexpected binary message"
        ws.OnTextMessage(message) -> {
          io.println("Received WebSocket message: " <> message)
          // TODO: Parse and handle different message types
          #(model, effect.none())
        }
        ws.OnClose(close_reason) -> {
          echo #("WebSocket error", close_reason)
          let error_toast =
            toast.create_error_toast("Socket connection lost - reconnecting...")
          show_toast(model, error_toast)
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
  html.div([], [
    // Main content based on app state
    case model.app_state {
      LoggedIn(shared_user.UserDto(_id, username, _email, _email_verified)) ->
        html.div([], [html.text("Welcome " <> username <> "!")])
      PreLogin(state) ->
        element.map(pre_login.view_login_signup(state), fn(pre_msg) {
          PreLoginMsg(pre_msg)
        })
    },
    // Toast notifications overlay
    toast.view_toasts(model.global_state.toasts),
  ])
}
