// IMPORTS ---------------------------------------------------------------------

import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import lustre
import lustre/attribute.{class, name, placeholder, type_}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event.{on_click}
import rsvp

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  PreLogin(PreLoginState)
  LoggedIn
}

// TODO: too repetititve - check https://github.com/lustre-labs/lustre/blob/main/examples/02-inputs/04-forms/src/app.gleam 
type PreLoginState {
  PreLoginState(
    mode: PreLoginMode,
    username: String,
    email: String,
    password: String,
    password_confirm: String,
  )
}

type PreLoginMode {
  Login
  Register
}

fn init(_) -> #(Model, Effect(Msg)) {
  // let effect = fetch_todos(on_response: ApiReturnedTodos)

  #(
    PreLogin(PreLoginState(
      mode: Login,
      username: "",
      email: "",
      password: "",
      password_confirm: "",
    )),
    effect.none(),
  )
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  UserSetPreLoginMode(PreLoginMode)
  UserChangeUserName(String)
  UserChangePassword(String)
  UserChangeEmail(String)
  UserChangePasswordConfirm(String)
  UserSubmitPreLogin
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let model = case msg {
    UserSetPreLoginMode(mode) ->
      case model {
        PreLogin(s) -> PreLogin(PreLoginState(..s, mode: mode))
        _ -> model
      }

    UserChangeEmail(updated) ->
      case model {
        PreLogin(s) -> PreLogin(PreLoginState(..s, email: updated))
        _ -> model
      }

    UserChangePassword(updated) ->
      case model {
        PreLogin(s) -> PreLogin(PreLoginState(..s, password: updated))
        _ -> model
      }

    UserChangePasswordConfirm(updated) ->
      case model {
        PreLogin(s) -> PreLogin(PreLoginState(..s, password_confirm: updated))
        _ -> model
      }

    UserChangeUserName(updated) ->
      case model {
        PreLogin(s) -> PreLogin(PreLoginState(..s, username: updated))
        _ -> model
      }

    UserSubmitPreLogin -> todo
  }

  echo model

  #(model, effect.none())
}

// VIEW ------------------------------------------------------------------------
fn view(model: Model) -> Element(Msg) {
  case model {
    LoggedIn -> html.div([], [html.text("Welcome!")])
    PreLogin(state) -> view_login_register(state.mode)
  }
}

fn view_login_register(mode: PreLoginMode) -> Element(Msg) {
  let toggle_button = {
    let active_toggle_button_class =
      class(
        "flex-1 px-3 py-2 rounded-md text-sm font-medium bg-white text-blue-600 shadow",
      )
    let inactive_toggle_button_class =
      class(
        "flex-1 px-3 py-2 rounded-md text-sm font-medium text-gray-600 hover:text-gray-900",
      )
    html.div([class("flex bg-gray-100 rounded-md p-1")], [
      html.button(
        [
          case mode {
            Login -> active_toggle_button_class
            Register -> inactive_toggle_button_class
          },
          event.on_click(UserSetPreLoginMode(Login)),
          type_("button"),
        ],
        [html.text("Login")],
      ),
      html.button(
        [
          case mode {
            Register -> active_toggle_button_class
            Login -> inactive_toggle_button_class
          },
          event.on_click(UserSetPreLoginMode(Register)),
          type_("button"),
        ],
        [html.text("Register")],
      ),
    ])
  }

  let title =
    html.h1([class("text-xl font-bold text-blue-600")], [
      html.text(case mode {
        Login -> "Login"
        Register -> "Create account"
      }),
    ])

  let fields = case mode {
    Login -> [
      html_input("Username", "text", "username", "your_username", fn(x) {
        UserChangeUserName(x)
      }),
      html_input("Password", "password", "password", "••••••••", fn(x) {
        UserChangePassword(x)
      }),
    ]
    Register -> [
      html_input("Username", "text", "username", "your_username", fn(x) {
        UserChangeUserName(x)
      }),
      html_input("Email", "email", "email", "you@example.com", fn(x) {
        UserChangeEmail(x)
      }),
      html_input("Password", "password", "password", "••••••••", fn(x) {
        UserChangePassword(x)
      }),
      html_input(
        "Confirm password",
        "password",
        "password_confirm",
        "••••••••",
        fn(x) { UserChangePasswordConfirm(x) },
      ),
    ]
  }

  let submit_button =
    html.button(
      [
        class(
          "mt-2 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded",
        ),
        type_("submit"),
      ],
      [
        html.text(case mode {
          Login -> "Log in"
          Register -> "Create account"
        }),
      ],
    )

  html.div(
    [class("flex justify-center items-center w-full h-screen bg-gray-50")],
    [
      html.form(
        [
          class(
            "flex flex-col gap-5 p-8 w-80 border rounded-lg shadow-md bg-white",
          ),
          type_("submit"),
          event.on_submit(fn(_) { UserSubmitPreLogin }),
        ],
        list.flatten([
          [toggle_button, title],
          fields,
          [submit_button],
        ]),
      ),
    ],
  )
}

fn html_input(
  label: String,
  type_: String,
  name: String,
  placeholder: String,
  msg: fn(String) -> msg,
) -> Element(msg) {
  html.div([class("flex flex-col gap-1")], [
    html.label([class("text-sm font-medium text-gray-700")], [
      html.text(label),
    ]),
    html.input([
      class(
        "border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500",
      ),
      attribute.type_(type_),
      attribute.name(name),
      attribute.placeholder(placeholder),
      event.on_input(msg),
    ]),
  ])
}
