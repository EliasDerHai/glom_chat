// IMPORTS ---------------------------------------------------------------------

import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import pre_login

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// MODEL -----------------------------------------------------------------------

pub type Model {
  PreLogin(pre_login.PreLoginState)
  LoggedIn
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  // let effect = fetch_todos(on_response: ApiReturnedTodos)

  #(PreLogin(pre_login.init()), effect.none())
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  PreLoginMsg(pre_login.PreLoginMsg)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model, msg {
    PreLogin(model), PreLoginMsg(msg) -> {
      let #(model, pre_login_effect) = pre_login.update(model, msg)
      #(
        PreLogin(model),
        effect.map(pre_login_effect, fn(msg) { PreLoginMsg(msg) }),
      )
    }

    LoggedIn, _ -> #(LoggedIn, effect.none())
  }
}

// VIEW ------------------------------------------------------------------------
fn view(model: Model) -> Element(Msg) {
  case model {
    LoggedIn -> html.div([], [html.text("Welcome!")])
    PreLogin(state) ->
      element.map(pre_login.view_login_signup(state), fn(pre_msg) {
        PreLoginMsg(pre_msg)
      })
  }
}
