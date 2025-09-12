import endpoints
import gleam/bool
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import lustre
import lustre/attribute.{type Attribute}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import lustre/event
import rsvp
import shared_session.{type SessionDto}
import shared_user.{type UserDto, CreateUserDto, Username}
import util/form.{type FormField}
import util/toast

// COMPONENT API ---------------------------------------------------------------

pub fn register() -> Result(Nil, lustre.Error) {
  let component = lustre.component(init, update, view, [])
  lustre.register(component, "pre-login")
}

pub fn element(attributes: List(Attribute(msg))) -> Element(msg) {
  element.element("pre-login", attributes, [])
}

pub fn on_login_success(handler: fn(SessionDto) -> msg) -> Attribute(msg) {
  event.on("login-success", {
    decode.at(["detail"], shared_session.decode_dto()) |> decode.map(handler)
  })
}

pub fn on_show_toast(handler: fn(toast.Toast) -> msg) -> Attribute(msg) {
  event.on("show-toast", {
    decode.at(["detail"], toast.decode_toast()) |> decode.map(handler)
  })
}

// MODEL -----------------------------------------------------------------------
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

pub fn init(_) -> #(PreLoginState, Effect(PreLoginMsg)) {
  let default_validators = [
    form.validator_nonempty(),
    form.validator_min_length(5),
  ]

  let model =
    PreLoginState(
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
    )

  #(model, effect.none())
}

// UPDATE -----------------------------------------------------------------------
pub type PreLoginMsg {
  UserSetPreLoginMode(PreLoginMode)
  UserSubmitForm
  UserChangeForm(PreLoginFormProperty, String)
  UserBlurForm(PreLoginFormProperty)
  ApiRespondSignupRequest(Result(UserDto, rsvp.Error))
  ApiRespondLoginRequest(Result(SessionDto, rsvp.Error))
}

pub type PreLoginFormProperty {
  LoginUsername
  LoginPassword
  SignupUsername
  SignupEmail
  SignupPassword
  SignupPasswordConfirm
}

pub fn evaluate_matching_passwords(model: SignupDetails) -> SignupDetails {
  let #(password_field, password_confirm_field) = case
    model.password.value != model.password_confirm.value
    && model.password.touch == form.Dirty
    && model.password_confirm.touch == form.Dirty
  {
    True -> #(
      form.set_custom_error(model.password, PasswordMissmatch),
      form.set_custom_error(model.password_confirm, PasswordMissmatch),
    )
    False -> #(
      form.clear_custom_error(model.password),
      form.clear_custom_error(model.password_confirm),
    )
  }
  SignupFormData(
    ..model,
    password: password_field,
    password_confirm: password_confirm_field,
  )
}

pub fn update(
  model: PreLoginState,
  msg: PreLoginMsg,
) -> #(PreLoginState, Effect(PreLoginMsg)) {
  let update_login = fn(f: fn(LoginDetails) -> LoginDetails) {
    PreLoginState(..model, login_form_data: f(model.login_form_data))
  }
  let update_signup = fn(f: fn(SignupDetails) -> SignupDetails) {
    PreLoginState(..model, signup_form_data: f(model.signup_form_data))
  }

  let model = case msg {
    UserSetPreLoginMode(mode) -> PreLoginState(..model, mode: mode)

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
            |> evaluate_matching_passwords
          })
        SignupPasswordConfirm -> {
          update_signup(fn(r) {
            SignupFormData(
              ..r,
              password_confirm: form.set_value(r.password_confirm, value),
            )
            |> evaluate_matching_passwords
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
            |> evaluate_matching_passwords
          })
        SignupPasswordConfirm -> {
          update_signup(fn(r) {
            SignupFormData(..r, password_confirm: form.eval(r.password_confirm))
            |> evaluate_matching_passwords
          })
        }
      }
    }

    ApiRespondSignupRequest(Ok(_)) -> PreLoginState(..model, mode: Login)
    ApiRespondSignupRequest(Error(_)) -> model
    ApiRespondLoginRequest(_) -> model
    UserSubmitForm -> model
  }

  let effect = case msg {
    UserSubmitForm ->
      case model.mode {
        Signup ->
          send_signup_req(model.signup_form_data, ApiRespondSignupRequest)
        Login -> send_login_req(model.login_form_data, ApiRespondLoginRequest)
      }

    ApiRespondSignupRequest(result) ->
      case result {
        Ok(signup_response) -> {
          let toast_msg =
            toast.create_info_toast(
              "Signup successful for user: " <> signup_response.username.v,
            )
          event.emit("show-toast", toast.encode_toast(toast_msg))
        }
        Error(e) -> {
          let error_message = case e {
            rsvp.HttpError(r) if r.body == "username-taken" ->
              "Signup failed:\nUsername is already taken"
            rsvp.HttpError(r) if r.body == "email-taken" ->
              "Signup failed:\nEmail is already in use"
            _ -> "Signup failed"
          }
          let toast_msg = toast.create_error_toast(error_message)
          event.emit("show-toast", toast.encode_toast(toast_msg))
        }
      }

    ApiRespondLoginRequest(result) ->
      case result {
        Ok(session_dto) ->
          event.emit("login-success", shared_session.to_json(session_dto))
        Error(e) -> {
          let error_message = case e {
            rsvp.HttpError(r) if r.status == 401 ->
              "Login failed:\nWrong username/password"
            _ -> "Login failed:\nUnexpected Error"
          }
          let toast_msg = toast.create_error_toast(error_message)
          event.emit("show-toast", toast.encode_toast(toast_msg))
        }
      }

    _ -> effect.none()
  }

  #(model, effect)
}

// VIEW ------------------------------------------------------------------------

fn view(model: PreLoginState) -> Element(PreLoginMsg) {
  let mode = model.mode
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
        model.login_form_data.username,
      ),
      html_input(
        mode,
        LoginPassword,
        "Password",
        "password",
        "password",
        "••••••••",
        model.login_form_data.password,
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
        model.signup_form_data.username,
      ),
      html_input(
        mode,
        SignupEmail,
        "Email",
        "email",
        "email",
        "you@example.com",
        model.signup_form_data.email,
      ),
      html_input(
        mode,
        SignupPassword,
        "Password",
        "password",
        "password",
        "••••••••",
        model.signup_form_data.password,
      ),
      html_input(
        mode,
        SignupPasswordConfirm,
        "Confirm password",
        "password",
        "password_confirm",
        "••••••••",
        model.signup_form_data.password_confirm,
      ),
    ]
  }

  let submit_allowed = case mode {
    Login ->
      model.login_form_data.username |> form.field_is_valid
      && model.login_form_data.password |> form.field_is_valid
    Signup ->
      model.signup_form_data.username |> form.field_is_valid
      && model.signup_form_data.email |> form.field_is_valid
      && model.signup_form_data.password |> form.field_is_valid
      && model.signup_form_data.password_confirm |> form.field_is_valid
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

fn send_signup_req(
  signup_details: SignupDetails,
  on_response handle_response: fn(Result(UserDto, rsvp.Error)) -> PreLoginMsg,
) -> Effect(PreLoginMsg) {
  let url = endpoints.users()
  let handler = rsvp.expect_json(shared_user.decode_user_dto(), handle_response)

  let create =
    CreateUserDto(
      signup_details.username.value
        |> form.get_form_field_value_as_string
        |> Username,
      signup_details.email.value |> form.get_form_field_value_as_string,
      signup_details.password.value |> form.get_form_field_value_as_string,
    )

  case request.to(url) {
    Ok(request) ->
      request
      |> request.set_method(http.Post)
      |> request.set_header("content-type", "application/json")
      |> request.set_body(json.to_string(
        create |> shared_user.create_user_dto_to_json,
      ))
      |> rsvp.send(handler)

    Error(_) -> panic as { "Failed to create request to " <> url }
  }
}

fn send_login_req(
  login_details: LoginDetails,
  on_response handle_response: fn(Result(SessionDto, rsvp.Error)) -> PreLoginMsg,
) -> Effect(PreLoginMsg) {
  let url = endpoints.login()
  let handler = rsvp.expect_json(shared_session.decode_dto(), handle_response)

  let create =
    shared_user.UserLoginDto(
      login_details.username.value |> form.get_form_field_value_as_string,
      login_details.password.value |> form.get_form_field_value_as_string,
    )

  case request.to(url) {
    Ok(request) ->
      request
      |> request.set_method(http.Post)
      |> request.set_header("content-type", "application/json")
      |> request.set_body(json.to_string(
        create |> shared_user.user_loging_dto_to_json,
      ))
      |> rsvp.send(handler)

    Error(_) -> panic as { "Failed to create request to " <> url }
  }
}

// VIEW -----------------------------------------------------------------------

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
  property: PreLoginFormProperty,
  label: String,
  type_: String,
  name: String,
  placeholder: String,
  field: DefaultFormField,
) -> Element(PreLoginMsg) {
  let key =
    case mode {
      Login -> "login_"
      Signup -> "signup_"
    }
    <> name

  let error = field |> get_error_text
  let value = field.value |> form.get_form_field_value_as_string

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
            attribute.value(value),
            event.on_change(fn(value: String) {
              UserChangeForm(property, value)
            }),
            event.on_blur(UserBlurForm(property)),
          ]),
          ..error_element
        ],
      ),
    ),
  ])
}
