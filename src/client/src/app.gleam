// IMPORTS ---------------------------------------------------------------------

import form.{type FormField}
import gleam/bool
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/string
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
    signup_form_data: SignupFormData,
  )
}

type DefaultFormField =
  FormField(String, Nil)

pub type LoginFormData {
  LoginFormData(username: DefaultFormField, password: DefaultFormField)
}

pub type SignupFormData {
  SignupFormData(
    username: DefaultFormField,
    email: DefaultFormField,
    password: DefaultFormField,
    password_confirm: DefaultFormField,
  )
}

pub type PreLoginMode {
  Login
  Signup
}

pub fn init(_) -> #(Model, Effect(Msg)) {
  // let effect = fetch_todos(on_response: ApiReturnedTodos)

  let default_validators = [
    form.validator_nonempty(),
    form.validator_min_length(5),
  ]

  #(
    PreLogin(PreLoginState(
      mode: Login,
      login_form_data: LoginFormData(
        username: form.form_field(default_validators),
        password: form.form_field(default_validators),
      ),
      signup_form_data: SignupFormData(
        username: form.form_field(default_validators),
        email: form.form_field(default_validators),
        password: form.form_field(default_validators),
        password_confirm: form.form_field(default_validators),
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
  SignupUsername
  SignupEmail
  SignupPassword
  SignupPasswordConfirm
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
      let update_signup = fn(f: fn(SignupFormData) -> SignupFormData) {
        PreLoginState(
          ..pre_login_model,
          signup_form_data: f(pre_login_model.signup_form_data),
        )
      }

      case field {
        // Login form fields
        LoginUsername ->
          update_login(fn(l) {
            LoginFormData(..l, username: form.set_value(l.username, value))
          })
        LoginPassword ->
          update_login(fn(l) {
            LoginFormData(..l, password: form.set_value(l.password, value))
          })

        // Signup form fields
        SignupUsername ->
          update_signup(fn(r) {
            SignupFormData(..r, username: form.set_value(r.username, value))
          })
        SignupEmail ->
          update_signup(fn(r) {
            SignupFormData(..r, email: form.set_value(r.email, value))
          })
        SignupPassword ->
          update_signup(fn(r) {
            SignupFormData(..r, password: form.set_value(r.password, value))
          })
        SignupPasswordConfirm ->
          update_signup(fn(r) {
            SignupFormData(
              ..r,
              password_confirm: form.set_value(r.password_confirm, value),
            )
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
    PreLogin(state) -> view_login_signup(state)
  }
}

fn view_login_signup(state: PreLoginState) -> Element(Msg) {
  let mode = state.mode
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
            Signup -> inactive_toggle_button_class
          },
          event.on_click(UserSetPreLoginMode(Login)),
          attribute.type_("button"),
        ],
        [html.text("Login")],
      ),
      html.button(
        [
          case mode {
            Signup -> active_toggle_button_class
            Login -> inactive_toggle_button_class
          },
          event.on_click(UserSetPreLoginMode(Signup)),
          attribute.type_("button"),
        ],
        [html.text("Signup")],
      ),
    ])
  }

  let title =
    html.h1([attribute.class("text-xl font-bold text-blue-600")], [
      html.text(case mode {
        Login -> "Login"
        Signup -> "Create account"
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
    Signup -> [
      html_input("Username", "text", "username", "your_username", fn(x) {
        UserChangeForm(SignupUsername, x)
      }),
      html_input("Email", "email", "email", "you@example.com", fn(x) {
        UserChangeForm(SignupEmail, x)
      }),
      html_input("Password", "password", "password", "••••••••", fn(x) {
        UserChangeForm(SignupPassword, x)
      }),
      html_input(
        "Confirm password",
        "password",
        "password_confirm",
        "••••••••",
        fn(x) { UserChangeForm(SignupPasswordConfirm, x) },
      ),
    ]
  }

  let submit_allowed = case mode {
    Login -> state.login_form_data.username |> form.is_valid
    Signup -> state.signup_form_data.username |> form.is_valid
  }

  echo submit_allowed

  let submit_button =
    html.button(
      [
        attribute.class(
          "mt-2 bg-blue-600 text-white font-semibold py-2 px-4 rounded transition-colors "
          <> "disabled:bg-gray-300 "
          <> "hover:bg-blue-700 ",
        ),
        attribute.type_("submit"),
        attribute.disabled(submit_allowed |> bool.negate),
      ],
      [
        html.text(case mode {
          Login -> "Log in"
          Signup -> "Create account"
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
