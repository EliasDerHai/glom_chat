// IMPORTS ---------------------------------------------------------------------

import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import pre_login.{type PreLoginMsg}
import shared_user
import toast.{type Toast}
import util/time_util

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
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model.app_state, msg {
    // ### TOASTS ###
    _, PreLoginMsg(pre_login.ShowToast(toast_msg)) | _, ShowToast(toast_msg) -> {
      let new_toasts = toast.add_toast(model.global_state.toasts, toast_msg)
      let new_global_state = GlobalState(new_toasts)
      let remove_toast_after_timeout_effect =
        effect.from(fn(dispatch) {
          time_util.set_timeout(
            fn() { dispatch(RemoveToast(toast_msg.id)) },
            toast_msg.duration,
          )
        })

      #(
        Model(model.app_state, new_global_state),
        remove_toast_after_timeout_effect,
      )
    }

    _, RemoveToast(toast_id) -> {
      let new_toasts =
        toast.remove_toast_by_id(model.global_state.toasts, toast_id)
      let new_global_state = GlobalState(new_toasts)
      #(Model(model.app_state, new_global_state), effect.none())
    }

    // ### APP ###
    PreLogin(pre_login_model), PreLoginMsg(msg) -> {
      let #(pre_login_model, pre_login_effect) =
        pre_login.update(pre_login_model, msg)

      case msg {
        pre_login.ApiRespondLoginRequest(Ok(user_dto)) -> #(
          Model(LoggedIn(user_dto), model.global_state),
          effect.map(pre_login_effect, fn(msg) { PreLoginMsg(msg) }),
        )

        _ -> #(
          Model(PreLogin(pre_login_model), model.global_state),
          effect.map(pre_login_effect, fn(msg) { PreLoginMsg(msg) }),
        )
      }
    }

    LoggedIn(model), PreLoginMsg(msg) -> {
      echo #(model, msg)
      panic as "Unexpected combination"
    }
  }
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
