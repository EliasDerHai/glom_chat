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
  PreLogin(PreLoginMode)
  LoggedIn
}

//type PreLoginMode {
//  Login(user_name: String, password: String)
//  Register(
//    user_name: String,
//    email: String,
//    password: String,
//    password_repeat: String,
//  )
//}

type PreLoginMode {
  Login
  Register
}

fn init(_) -> #(Model, Effect(Msg)) {
  // let effect = fetch_todos(on_response: ApiReturnedTodos)

  #(PreLogin(Login), effect.none())
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  SetPreLoginMode(PreLoginMode)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let model = case msg {
    SetPreLoginMode(mode) -> PreLogin(mode)
  }

  #(model, effect.none())
}

// VIEW ------------------------------------------------------------------------
fn view(model: Model) -> Element(Msg) {
  case model {
    LoggedIn -> html.div([], [html.text("Welcome!")])
    PreLogin(mode) -> view_login_register(mode)
  }
}

fn view_login_register(mode: PreLoginMode) -> Element(Msg) {
  let active_toggle_button =
    class(
      "flex-1 px-3 py-2 rounded-md text-sm font-medium bg-white text-blue-600 shadow",
    )
  let inactive_toggle_button =
    class(
      "flex-1 px-3 py-2 rounded-md text-sm font-medium text-gray-600 hover:text-gray-900",
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
        ],
        [
          // --- toggle button ---
          html.div([class("flex bg-gray-100 rounded-md p-1")], [
            html.button(
              [
                case mode {
                  Login -> active_toggle_button
                  Register -> inactive_toggle_button
                },
                event.on_click(SetPreLoginMode(Login)),
                type_("button"),
              ],
              [html.text("Login")],
            ),
            html.button(
              [
                case mode {
                  Register -> active_toggle_button
                  Login -> inactive_toggle_button
                },
                event.on_click(SetPreLoginMode(Register)),
                type_("button"),
              ],
              [html.text("Register")],
            ),
          ]),

          // title
          html.h1([class("text-xl font-bold text-blue-600")], [
            html.text(case mode {
              Login -> "Login"
              Register -> "Create account"
            }),
          ]),

          // username
          html.div([class("flex flex-col gap-1")], [
            html.label([class("text-sm font-medium text-gray-700")], [
              html.text("Username"),
            ]),
            html.input([
              class(
                "border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500",
              ),
              type_("text"),
              attribute.name("username"),
              placeholder("yourname"),
            ]),
          ]),

          // email (register only)
          case mode {
            Register ->
              html.div([class("flex flex-col gap-1")], [
                html.label([class("text-sm font-medium text-gray-700")], [
                  html.text("Email"),
                ]),
                html.input([
                  class(
                    "border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500",
                  ),
                  type_("email"),
                  name("email"),
                  placeholder("you@example.com"),
                ]),
              ])
            _ -> html_none()
          },

          // password
          html.div([class("flex flex-col gap-1")], [
            html.label([class("text-sm font-medium text-gray-700")], [
              html.text("Password"),
            ]),
            html.input([
              class(
                "border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500",
              ),
              type_("password"),
              name("password"),
              placeholder("••••••••"),
            ]),
          ]),

          // password confirm (register only)
          case mode {
            Register ->
              html.div([class("flex flex-col gap-1")], [
                html.label([class("text-sm font-medium text-gray-700")], [
                  html.text("Confirm password"),
                ]),
                html.input([
                  class(
                    "border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500",
                  ),
                  type_("password"),
                  name("password_confirm"),
                  placeholder("••••••••"),
                ]),
              ])
            _ -> html_none()
          },

          // submit
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
          ),
        ],
      ),
    ],
  )
}

fn html_none() {
  html.span([], [])
}
