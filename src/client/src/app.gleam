// IMPORTS ---------------------------------------------------------------------

import form.{type FormField}
import gleam/bool
import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option
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
    login_form_data: LoginDetails,
    signup_form_data: SignupDetails,
  )
}

pub type CustomError {
  PasswordMissmatch
}

type DefaultFormField =
  FormField(CustomError)

pub type LoginDetails {
  LoginDetails(username: DefaultFormField, password: DefaultFormField)
}

pub type SignupDetails {
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
      login_form_data: LoginDetails(
        username: form.string_form_field(default_validators),
        password: form.string_form_field(default_validators),
      ),
      signup_form_data: SignupFormData(
        username: form.string_form_field(default_validators),
        email: form.string_form_field(default_validators),
        password: form.string_form_field(default_validators),
        password_confirm: form.string_form_field([form.validator_nonempty()]),
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
  UserBlurForm(PreLoginFormField)
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

pub fn update_pre_login(
  pre_login_model: PreLoginState,
  msg: Msg,
) -> PreLoginState {
  let update_login = fn(f: fn(LoginDetails) -> LoginDetails) {
    PreLoginState(
      ..pre_login_model,
      login_form_data: f(pre_login_model.login_form_data),
    )
  }
  let update_signup = fn(f: fn(SignupDetails) -> SignupDetails) {
    PreLoginState(
      ..pre_login_model,
      signup_form_data: f(pre_login_model.signup_form_data),
    )
  }

  case msg {
    UserSetPreLoginMode(mode) -> PreLoginState(..pre_login_model, mode: mode)

    UserChangeForm(field, value) -> {
      let value = form.StringField(value)

      case field {
        // Login form fields
        LoginUsername ->
          update_login(fn(l) {
            LoginDetails(..l, username: form.set_value(l.username, value))
          })
        LoginPassword ->
          update_login(fn(l) {
            LoginDetails(..l, password: form.set_value(l.password, value))
          })

        // Signup form fields
        SignupUsername -> {
          update_signup(fn(r) {
            let field = form.set_value(r.username, value)
            echo field
            SignupFormData(..r, username: field)
          })
        }
        SignupEmail ->
          update_signup(fn(r) {
            SignupFormData(..r, email: form.set_value(r.email, value))
          })
        SignupPassword ->
          update_signup(fn(r) {
            SignupFormData(..r, password: form.set_value(r.password, value))
          })
        SignupPasswordConfirm -> {
          update_signup(fn(r) {
            let field = form.set_value(r.password_confirm, value)
            let field = case r.password.value == r.password_confirm.value {
              False -> form.set_custom_error(field, PasswordMissmatch)
              True -> form.clear_custom_error(field)
            }
            SignupFormData(..r, password_confirm: field)
          })
        }
      }
    }
    UserBlurForm(field) -> {
      case field {
        // Login form fields
        LoginUsername ->
          update_login(fn(l) {
            LoginDetails(..l, username: form.eval(l.username))
          })
        LoginPassword ->
          update_login(fn(l) {
            LoginDetails(..l, password: form.eval(l.password))
          })

        // Signup form fields
        SignupUsername ->
          update_signup(fn(r) {
            SignupFormData(..r, username: form.eval(r.username))
          })
        SignupEmail ->
          update_signup(fn(r) { SignupFormData(..r, email: form.eval(r.email)) })
        SignupPassword ->
          update_signup(fn(r) {
            SignupFormData(..r, password: form.eval(r.password))
          })
        SignupPasswordConfirm -> {
          update_signup(fn(r) {
            let field = form.eval(r.password_confirm)
            let field = case r.password.value == r.password_confirm.value {
              False -> form.set_custom_error(field, PasswordMissmatch)
              True -> form.clear_custom_error(field)
            }
            SignupFormData(..r, password_confirm: field)
          })
        }
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
      html_input(
        mode,
        LoginUsername,
        "Username",
        "text",
        "username",
        "your_username",
        state.login_form_data.username |> get_error_text,
      ),
      html_input(
        mode,
        LoginPassword,
        "Password",
        "password",
        "password",
        "••••••••",
        state.login_form_data.password |> get_error_text,
      ),
    ]
    Signup -> [
      html_input(
        mode,
        SignupUsername,
        "Username",
        "text",
        "username",
        "your_username",
        state.signup_form_data.username |> get_error_text,
      ),
      html_input(
        mode,
        SignupEmail,
        "Email",
        "email",
        "email",
        "you@example.com",
        state.signup_form_data.email |> get_error_text,
      ),
      html_input(
        mode,
        SignupPassword,
        "Password",
        "password",
        "password",
        "••••••••",
        state.signup_form_data.password |> get_error_text,
      ),
      html_input(
        mode,
        SignupPasswordConfirm,
        "Confirm password",
        "password",
        "password_confirm",
        "••••••••",
        state.signup_form_data.password_confirm |> get_error_text,
      ),
    ]
  }

  let submit_allowed = case mode {
    Login ->
      state.login_form_data.username |> form.field_is_valid
      && state.login_form_data.password |> form.field_is_valid
    Signup ->
      state.signup_form_data.username |> form.field_is_valid
      && state.signup_form_data.email |> form.field_is_valid
      && state.signup_form_data.password |> form.field_is_valid
      && state.signup_form_data.password_confirm |> form.field_is_valid
  }

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

pub fn get_error_text(field: FormField(CustomError)) -> option.Option(String) {
  form.get_error(field)
  |> option.map(fn(e) {
    case e {
      form.Custom(PasswordMissmatch) -> "passwords don't match"
      form.Predefined(form.Empty) -> "cannot be empty"
      form.Predefined(form.MinLength(is:, min:)) ->
        "min length "
        <> int.to_string(min)
        <> " (is "
        <> int.to_string(is)
        <> ")"
    }
  })
}

pub fn html_input(
  mode: PreLoginMode,
  field: PreLoginFormField,
  label: String,
  type_: String,
  name: String,
  placeholder: String,
  error: option.Option(String),
) -> Element(Msg) {
  let key =
    case mode {
      Login -> "login_"
      Signup -> "signup_"
    }
    <> name

  let error_element = case error {
    option.None -> []
    option.Some(error_text) -> [
      html.p([attribute.class("mt-1 text-sm text-red-600")], [
        html.text(error_text),
      ]),
    ]
  }

  let input_classes = case error {
    option.Some(_) ->
      "border rounded px-3 py-2 focus:outline-none focus:ring-2 
         border-red-500 focus:ring-red-500 focus:border-red-500 
         placeholder-red-400"
    option.None ->
      "border border-gray-300 rounded px-3 py-2 focus:outline-none 
         focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
  }

  echo #(key, error)

  keyed.div([], [
    #(
      key,
      html.label(
        [
          attribute.class(
            "flex flex-col gap-1 text-sm font-medium text-gray-700",
          ),
        ],
        [
          html.text(label),
          html.input([
            attribute.class(input_classes),
            attribute.type_(type_),
            attribute.name(name),
            attribute.placeholder(placeholder),
            event.on_change(fn(value: String) { UserChangeForm(field, value) }),
            event.on_blur(UserBlurForm(field)),
          ]),
          ..error_element
        ],
      ),
    ),
  ])
}
