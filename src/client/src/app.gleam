// IMPORTS ---------------------------------------------------------------------

import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import lustre
import lustre/attribute
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
    login_form_data: LoginFormData,
    register_form_data: RegisterFormData,
  )
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

pub type PreLoginMode {
  Login
  Register
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  // let effect = fetch_todos(on_response: ApiReturnedTodos)

  #(
    PreLogin(PreLoginState(
      mode: Login,
      login_form_data: LoginFormData(username: "", password: ""),
      register_form_data: RegisterFormData(
        username: "",
        email: "",
        password: "",
        password_confirm: "",
      ),
    )),
    effect.none(),
  )
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  UserSetPreLoginMode(PreLoginMode)
  UserSubmitForm
  UserChangeForm(PreLoginFormField, String)
}

pub type PreLoginFormField {
  LoginUsername
  LoginPassword
  RegisterUsername
  RegisterEmail
  RegisterPassword
  RegisterPasswordConfirm
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let model = case model {
    LoggedIn -> todo
    PreLogin(pre_login_model) ->
      PreLogin(update_pre_login(pre_login_model, msg))
  }

  #(model, effect.none())
}

fn update_pre_login(pre_login_model: PreLoginState, msg: Msg) -> PreLoginState {
  case msg {
    UserSetPreLoginMode(mode) -> PreLoginState(..pre_login_model, mode: mode)

    UserChangeForm(field, value) -> {
      let update_login = fn(f: fn(LoginFormData) -> LoginFormData) {
        PreLoginState(
          ..pre_login_model,
          login_form_data: f(pre_login_model.login_form_data),
        )
      }
      let update_register = fn(f: fn(RegisterFormData) -> RegisterFormData) {
        PreLoginState(
          ..pre_login_model,
          register_form_data: f(pre_login_model.register_form_data),
        )
      }

      case field {
        // Login form fields
        LoginUsername ->
          update_login(fn(l) { LoginFormData(..l, username: value) })
        LoginPassword ->
          update_login(fn(l) { LoginFormData(..l, password: value) })

        // Register form fields
        RegisterUsername ->
          update_register(fn(r) { RegisterFormData(..r, username: value) })
        RegisterEmail ->
          update_register(fn(r) { RegisterFormData(..r, email: value) })
        RegisterPassword ->
          update_register(fn(r) { RegisterFormData(..r, password: value) })
        RegisterPasswordConfirm ->
          update_register(fn(r) {
            RegisterFormData(..r, password_confirm: value)
          })
      }
    }

    UserSubmitForm -> todo
  }
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
      attribute.class(
        "flex-1 px-3 py-2 rounded-md text-sm font-medium bg-white text-blue-600 shadow",
      )
    let inactive_toggle_button_class =
      attribute.class(
        "flex-1 px-3 py-2 rounded-md text-sm font-medium text-gray-600 hover:text-gray-900",
      )
    html.div([attribute.class("flex bg-gray-100 rounded-md p-1")], [
      html.button(
        [
          case mode {
            Login -> active_toggle_button_class
            Register -> inactive_toggle_button_class
          },
          event.on_click(UserSetPreLoginMode(Login)),
          attribute.type_("button"),
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
          attribute.type_("button"),
        ],
        [html.text("Register")],
      ),
    ])
  }

  let title =
    html.h1([attribute.class("text-xl font-bold text-blue-600")], [
      html.text(case mode {
        Login -> "Login"
        Register -> "Create account"
      }),
    ])

  let fields = case mode {
    Login -> [
      html_input("Username", "text", "username", "your_username", fn(x) {
        UserChangeForm(LoginUsername, x)
      }),
      html_input("Password", "password", "password", "••••••••", fn(x) {
        UserChangeForm(LoginPassword, x)
      }),
    ]
    Register -> [
      html_input("Username", "text", "username", "your_username", fn(x) {
        UserChangeForm(RegisterUsername, x)
      }),
      html_input("Email", "email", "email", "you@example.com", fn(x) {
        UserChangeForm(RegisterEmail, x)
      }),
      html_input("Password", "password", "password", "••••••••", fn(x) {
        UserChangeForm(RegisterPassword, x)
      }),
      html_input(
        "Confirm password",
        "password",
        "password_confirm",
        "••••••••",
        fn(x) { UserChangeForm(RegisterPasswordConfirm, x) },
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
      ],
      [
        html.text(case mode {
          Login -> "Log in"
          Register -> "Create account"
        }),
      ],
    )

  html.div(
    [
      attribute.class(
        "flex justify-center items-center w-full h-screen bg-gray-50",
      ),
    ],
    [
      html.form(
        [
          attribute.class(
            "flex flex-col gap-5 p-8 w-80 border rounded-lg shadow-md bg-white",
          ),
          attribute.type_("submit"),
          event.on_submit(fn(_) { UserSubmitForm }),
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
  msg: fn(String) -> msg,
) -> Element(msg) {
  html.div([attribute.class("flex flex-col gap-1")], [
    html.label([attribute.class("text-sm font-medium text-gray-700")], [
      html.text(label),
    ]),
    html.input([
      attribute.class(
        "border rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500",
      ),
      attribute.type_(type_),
      attribute.name(name),
      attribute.placeholder(placeholder),
      event.on_input(msg),
    ]),
  ])
}
