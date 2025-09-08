// IMPORTS ---------------------------------------------------------------------

import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import pre_login
import toast

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
  LoggedIn
}

/// separate global state incl.
/// - toasts 
/// - configs (potentially)
/// shouldn't relate to business logic
pub type GlobalState {
  GlobalState(toasts: List(toast.Toast))
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  let model = Model(PreLogin(pre_login.init()), GlobalState([]))

  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  PreLoginMsg(pre_login.PreLoginMsg)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model.app_state, msg {
    PreLogin(pre_login_model), PreLoginMsg(msg) -> {
      let #(pre_login_model, pre_login_effect) =
        pre_login.update(pre_login_model, msg)
      #(
        Model(PreLogin(pre_login_model), model.global_state),
        effect.map(pre_login_effect, fn(msg) { PreLoginMsg(msg) }),
      )
    }

    LoggedIn, _ -> #(Model(LoggedIn, model.global_state), effect.none())
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  case model.app_state {
    LoggedIn -> html.div([], [html.text("Welcome!")])
    PreLogin(state) ->
      element.map(pre_login.view_login_signup(state), fn(pre_msg) {
        PreLoginMsg(pre_msg)
      })
  }
}
