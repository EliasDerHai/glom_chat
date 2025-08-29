// IMPORTS ---------------------------------------------------------------------

import formal/form.{type Form}
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/result
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

pub type Model {
  PreLogin(PreLoginState)
  LoggedIn
}

pub type PreLoginState {
  PreLoginState(
    mode: PreLoginMode,
    login_form: Form(LoginFormData),
    register_form: Form(RegisterFormData),
  )
}

pub type PreLoginMode {
  Login
  Register
}

pub type LoginFormData {
  LoginFormData(username: String, password: String)
}

pub type RegisterFormData {
  RegisterFormData(
    username: String,
    email: String,
    password: String,
    password_confirm: String,
  )
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  // let effect = fetch_todos(on_response: ApiReturnedTodos)

  let #(login_form, register_form) = get_forms()

  #(
    PreLogin(PreLoginState(
      mode: Login,
      login_form: login_form,
      register_form: register_form,
    )),
    effect.none(),
  )
}

fn get_forms() -> #(Form(LoginFormData), Form(RegisterFormData)) {
  #(
    form.new({
      use username <- form.field(
        "username",
        form.parse_string |> form.check_not_empty,
      )

      use password <- form.field(
        "password",
        form.parse_string |> form.check_not_empty,
      )

      form.success(LoginFormData(username:, password:))
    }),
    form.new({
      use username <- form.field(
        "username",
        form.parse_string |> form.check_not_empty,
      )

      use email <- form.field(
        "email",
        form.parse_string |> form.check_not_empty,
      )

      use password <- form.field(
        "password",
        form.parse_string |> form.check_not_empty,
      )

      use password_confirm <- form.field(
        "password_confirm",
        form.parse_string |> form.check_not_empty,
      )

      form.success(RegisterFormData(
        username:,
        email:,
        password:,
        password_confirm:,
      ))
    }),
  )
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  UserSetPreLoginMode(PreLoginMode)
  // submit
  UserSubmitLogin(Form(LoginFormData))
  UserSubmitRegister(Form(RegisterFormData))
  // change
  UserChangesLogin(Form(LoginFormData))
  UserChangesRegister(Form(RegisterFormData))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let model = case model {
    PreLogin(s) ->
      PreLogin(case msg {
        UserSetPreLoginMode(mode) -> PreLoginState(..s, mode: mode)
        UserSubmitLogin(data) -> {
          case data |> form.run {
            Error(e) -> PreLoginState(..s, login_form: e)
            Ok(_) -> todo
          }
        }
        UserSubmitRegister(data) -> {
          case data |> form.run {
            Error(e) -> PreLoginState(..s, register_form: e)
            Ok(_) -> todo
          }
        }
        UserChangesLogin(data) -> {
          let login_form: Form(LoginFormData) = case data |> form.run {
            Error(e) -> e
            Ok(_) -> data
          }
          // FIXME: buggy
          echo form.all_errors(login_form)
          PreLoginState(..s, login_form: login_form)
        }
        UserChangesRegister(data) -> {
          let register_form: Form(RegisterFormData) = case data |> form.run {
            Error(e) -> e
            Ok(_) -> data
          }
          // FIXME: buggy
          echo form.all_errors(register_form)
          PreLoginState(..s, register_form: register_form)
        }
      })
    _ -> model
  }

  #(model, effect.none())
}

// VIEW ------------------------------------------------------------------------
fn view(model: Model) -> Element(Msg) {
  case model {
    LoggedIn -> html.div([], [html.text("Welcome!")])
    PreLogin(state) -> view_login_register(state)
  }
}

fn view_login_register(state: PreLoginState) -> Element(Msg) {
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
          case state.mode {
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
          case state.mode {
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
      html.text(case state.mode {
        Login -> "Login"
        Register -> "Create account"
      }),
    ])

  let fields = case state.mode {
    Login -> [
      html_input("Username", "text", "username", "your_username", state),
      html_input("Password", "password", "password", "••••••••", state),
    ]
    Register -> [
      html_input("Username", "text", "username", "your_username", state),
      html_input("Email", "email", "email", "you@example.com", state),
      html_input("Password", "password", "password", "••••••••", state),
      html_input(
        "Confirm password",
        "password",
        "password_confirm",
        "••••••••",
        state,
      ),
    ]
  }

  let submit_button =
    html.button(
      [
        attribute.class(
          "mt-2 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded",
        ),
        attribute.type_("submit"),
        case state.mode {
          Login ->
            state.login_form
            |> form.run
            |> result.is_ok
          Register ->
            state.register_form
            |> form.run
            |> result.is_ok
        }
          |> attribute.disabled,
      ],
      [
        html.text(case state.mode {
          Login -> "Log in"
          Register -> "Create account"
        }),
      ],
    )

  let handle_submit = fn(state: PreLoginState, values: List(#(String, String))) {
    case state.mode {
      Login ->
        state.login_form
        |> form.set_values(values)
        |> UserSubmitLogin
      Register ->
        state.register_form
        |> form.set_values(values)
        |> UserSubmitRegister
    }
  }

  html.div(
    [class("flex justify-center items-center w-full h-screen bg-gray-50")],
    [
      html.form(
        [
          class(
            "flex flex-col gap-5 p-8 w-80 border rounded-lg shadow-md bg-white",
          ),
          event.on_submit(fn(values) { handle_submit(state, values) }),
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

pub fn html_input(
  label: String,
  type_: String,
  name: String,
  placeholder: String,
  state: PreLoginState,
) -> Element(Msg) {
  let handle_change = fn(state: PreLoginState, name: String, change: String) {
    case state.mode {
      Login ->
        state.login_form
        |> form.set_values([#(name, change)])
        |> UserChangesLogin
      Register ->
        state.register_form
        |> form.set_values([#(name, change)])
        |> UserChangesRegister
    }
  }

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
      event.on_change(fn(change) { handle_change(state, name, change) }),
    ]),
  ])
}
