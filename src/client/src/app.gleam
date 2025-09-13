import app_types.{
  type LoginState, type Model, type Msg, type NewConversation, ApiSearchResponse,
  CheckedAuth, Established, GlobalState, LoggedIn, LoginState, LoginSuccess,
  Model, NewConversation, NewConversationMsg, Pending, PreLogin, RemoveToast,
  ShowToast, UserModalClose, UserModalOpen, UserSearchInputChange, WsWrapper,
}
import endpoints
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/time/timestamp
import lustre
import lustre/attribute.{class, placeholder}
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre_websocket as ws
import pre_login
import rsvp
import shared_session
import shared_user
import util/cookie
import util/icons
import util/toast
import util/toast_state

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let app = lustre.application(init, update, view)

  let assert Ok(_) = pre_login.register()
  let assert Ok(_) = lustre.start(app, "#app", Nil)
}

// INIT ------------------------------------------------------------------------

pub fn init(_) -> #(Model, Effect(Msg)) {
  let model = Model(PreLogin, GlobalState([]))
  let effect = check_auth()

  #(model, effect)
}

fn check_auth() -> Effect(Msg) {
  let url = endpoints.me()
  let handler = rsvp.expect_json(shared_session.decode_dto(), CheckedAuth)

  case request.to(url) {
    Ok(request) ->
      request
      |> request.set_method(http.Get)
      |> rsvp.send(handler)
    Error(_) -> panic as { "Failed to create request to " <> url }
  }
}

// UPDATE ----------------------------------------------------------------------

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let noop = #(model, effect.none())
  let login = fn(session_dto) {
    #(
      Model(
        LoggedIn(LoginState(session_dto, Pending(timestamp.system_time()), None)),
        model.global_state,
      ),
      effect.none(),
      // TODO: revert ws.init(endpoints.socket_address(), WsWrapper),
    )
  }

  case msg {
    // ### AUTH CHECK ###
    CheckedAuth(Ok(session_dto)) -> session_dto |> login
    // no toast bc we do auth-check on-init
    CheckedAuth(Error(_)) -> noop

    // ### TOASTS ###
    ShowToast(toast_msg) -> toast_state.show_toast(model, toast_msg)
    RemoveToast(toast_id) -> toast_state.remove_toast(model, toast_id)

    // ### LOGIN ###
    LoginSuccess(session_dto) ->
      case model.app_state {
        PreLogin -> session_dto |> login
        // already logged in, ignore duplicate login
        LoggedIn(_) -> noop
      }

    // ### WEBSOCKET ###
    WsWrapper(socket_event) -> handle_socket_event(model, socket_event)

    // ### CHAT ###
    NewConversationMsg(msg) -> {
      let assert LoggedIn(login_state) = model.app_state
        as "must be logged in at this point"

      let #(new_conversation, effect) = case msg {
        UserModalOpen -> #(Some(NewConversation([])), effect.none())
        UserModalClose -> #(None, effect.none())
        UserSearchInputChange(v) -> #(
          login_state.new_conversation,
          search_usernames(v),
        )
        ApiSearchResponse(r) -> {
          case r {
            Error(_) -> {
              // TODO: add toast for failed request? 
              // echo e
              #(login_state.new_conversation, effect.none())
            }
            Ok(list) -> #(Some(NewConversation(list)), effect.none())
          }
        }
      }

      #(
        Model(
          LoggedIn(LoginState(..login_state, new_conversation:)),
          model.global_state,
        ),
        effect,
      )
    }
  }
}

fn search_usernames(value: String) -> Effect(Msg) {
  let url = endpoints.search_users()
  let handler =
    shared_user.decode_user_mini_dto()
    |> decode.list
    |> rsvp.expect_json(ApiSearchResponse)

  let body =
    value
    |> shared_user.Username
    |> shared_user.UsersByUsernameDto
    |> shared_user.users_by_username_dto_to_json
    |> json.to_string

  case request.to(url) {
    Ok(request) -> {
      let csrf_token = case cookie.get_cookie("csrf_token") {
        Some(csrf_token) -> csrf_token
        None -> ""
      }

      // TODO: cleanup log
      echo "csrf_token"
      echo csrf_token

      request
      |> request.set_method(http.Post)
      |> request.set_header("content-type", "application/json")
      |> request.set_header("x-csrf-token", csrf_token)
      |> request.set_body(body)
      |> rsvp.send(handler)
      |> effect.map(NewConversationMsg)
    }
    Error(_) -> panic as { "Failed to create request to " <> url }
  }
}

fn handle_socket_event(
  model: Model,
  socket_event: ws.WebSocketEvent,
) -> #(Model, Effect(Msg)) {
  case socket_event {
    ws.InvalidUrl -> panic as "invalid socket url"
    ws.OnOpen(socket) -> {
      io.println("WebSocket connected successfully")
      case model.app_state {
        LoggedIn(login_state) -> {
          let updated_login_state =
            LoginState(..login_state, web_socket: Established(socket))
          #(
            Model(LoggedIn(updated_login_state), model.global_state),
            effect.none(),
          )
        }
        _ -> #(model, effect.none())
      }
    }
    ws.OnBinaryMessage(_) -> panic as "received unexpected binary message"
    ws.OnTextMessage(message) -> {
      io.println("Received WebSocket message: " <> message)
      // TODO: Parse and handle different message types
      #(model, effect.none())
    }
    ws.OnClose(close_reason) -> {
      io.println("WebSocket closed: " <> string.inspect(close_reason))
      case model.app_state {
        LoggedIn(login_state) -> {
          let updated_login_state =
            LoginState(
              ..login_state,
              web_socket: Pending(timestamp.system_time()),
            )
          #(
            Model(LoggedIn(updated_login_state), model.global_state),
            ws.init(endpoints.socket_address(), WsWrapper),
          )
        }
        _ -> #(model, effect.none())
      }
    }
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let toasts = toast_state.toast_incl_socket_disconnet(model)

  html.div([], [
    // Main content based on app state
    case model.app_state {
      LoggedIn(login_state) -> view_chat(login_state)

      PreLogin ->
        pre_login.element([
          pre_login.on_login_success(LoginSuccess),
          pre_login.on_show_toast(ShowToast),
        ])
    },

    // Toast notifications overlay
    toast.view_toasts(toasts),
  ])
}

fn view_chat(model: LoginState) -> Element(Msg) {
  let LoginState(session, _, new_conv) = model

  html.div([class("flex h-screen bg-gray-50 text-gray-800")], [
    // Sidebar
    html.div([class("w-1/3 flex flex-col bg-white border-r border-gray-200")], [
      // Sidebar Header
      html.div([class("p-4 bUserModalOpenr-b border-gray-200")], [
        html.h2([class("text-xl font-bold text-blue-600")], [html.text("Chats")]),
      ]),
      // Search Input
      html.div([class("p-4")], [
        html.input([
          class(
            "w-full border border-gray-300 rounded px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
          ),
          placeholder("Search chats..."),
        ]),
      ]),
      // Chat List
      html.div([class("flex-1 overflow-y-auto")], [
        html.button(
          [
            class(
              "flex items-center gap-1 p-4 hover:bg-gray-100 cursor-pointer w-full",
            ),
            event.on_click(NewConversationMsg(UserModalOpen)),
          ],
          [
            icons.message_circle_plus([class("size-4")]),
            html.text("New conversation"),
          ],
        ),
        // Placeholder for chat list items
        html.div([class("p-4 hover:bg-gray-100 cursor-pointer")], [
          html.text("Chat with User A"),
        ]),
      ]),
    ]),

    // Main Content
    html.div([class("w-2/3 flex flex-col")], [
      // Header
      html.header([class("p-4 border-b border-gray-200 bg-white shadow-sm")], [
        html.h1([class("text-xl font-semibold")], [
          html.text("Welcome " <> session.username.v <> "!"),
        ]),
      ]),

      // Chat messages area
      html.main([class("flex-1 p-4 overflow-y-auto")], [
        html.p([], [html.text("Chat messages will appear here.")]),
      ]),

      // Message input area
      html.footer([class("p-4 bg-white border-t border-gray-200")], [
        html.div([class("flex")], [
          html.input([
            class(
              "w-full border border-gray-300 rounded-l-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
            ),
            placeholder("UserModalCloseyour message..."),
          ]),
          html.button(
            [
              class(
                "bg-blue-600 text-white font-semibold py-2 px-4 rounded-r-md transition-colors hover:bg-blue-700",
              ),
            ],
            [html.text("Send")],
          ),
        ]),
      ]),
    ]),
    case new_conv {
      Some(new_conv_state) -> view_new_conversation(new_conv_state)
      option.None -> html.div([], [])
    },
  ])
}

fn view_new_conversation(state: NewConversation) -> Element(Msg) {
  html.div([class("fixed inset-0 z-50")], [
    // Backdrop
    html.div(
      [
        class("absolute inset-0 bg-gray-400/70"),
        event.on_click(NewConversationMsg(UserModalClose)),
      ],
      [],
    ),

    // Modal
    html.div(
      [
        class(
          "absolute inset-0 grid place-items-center z-10 pointer-events-none",
        ),
      ],
      [
        html.div(
          [
            class(
              "pointer-events-auto bg-white rounded-lg shadow-xl p-6 w-full max-w-md",
            ),
          ],
          [
            html.h3([class("text-xl font-bold text-blue-600 mb-4")], [
              html.text("Start a new conversation"),
            ]),
            html.input([
              class(
                "w-full border border-gray-300 rounded px-3 py-2 mb-4 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500",
              ),
              placeholder("Search user..."),
              event.on_input(fn(value) {
                NewConversationMsg(UserSearchInputChange(value))
              }),
              // TODO: event.on_input(UpdateNewConversationQuery),
            ]),
            // TODO: search results
            html.div([], [
              case state.suggestions {
                [] ->
                  html.p([class("text-gray-500")], [
                    html.text("Search results will appear here."),
                  ])
                dtos ->
                  html.div(
                    [],
                    list.map(dtos, fn(dto) {
                      html.p([class("text-gray-500")], [
                        html.text(dto.username.v),
                      ])
                    }),
                  )
              },
            ]),
          ],
        ),
      ],
    ),
  ])
}
