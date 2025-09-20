import app_types.{
  type LoginState, type Model, type Msg, type NewConversation,
  type NewConversationMsg, ApiChatMessageResponse, ApiOnLogoutResponse,
  ApiSearchResponse, CheckedAuth, Established, GlobalState, LoggedIn, LoginState,
  LoginSuccess, Model, NewConversation, NewConversationMsg, Pending, PreLogin,
  RemoveToast, ShowToast, UserConversationPartnerSelect, UserModalClose,
  UserModalOpen, UserOnLogoutClick, UserOnSendSubmit, UserSearchInputChange,
  WsWrapper,
}
import endpoints
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import gleam/string
import gleam/time/calendar
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
import shared_chat.{type ClientChatMessage}
import shared_session
import shared_user.{Username, UsersByUsernameDto}
import util/button
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
  endpoints.get_request(
    endpoints.me(),
    shared_session.decode_dto(),
    CheckedAuth,
  )
}

// UPDATE ----------------------------------------------------------------------

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let noop = #(model, effect.none())
  let login = fn(session_dto) {
    #(
      Model(
        LoggedIn(LoginState(
          session_dto,
          Pending(timestamp.system_time()),
          None,
          None,
          dict.new(),
        )),
        model.global_state,
      ),
      effect.batch([
        ws.init(endpoints.socket_address(), WsWrapper),
        // TODO: load conversations
      ]),
    )
  }

  case msg {
    // ### AUTH CHECK ###
    CheckedAuth(Ok(session_dto)) -> session_dto |> login
    // no toast bc we do auth-check on-init
    CheckedAuth(Error(_)) -> #(
      Model(PreLogin, model.global_state),
      effect.none(),
    )

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

    // ### LOGOUT ###
    UserOnLogoutClick -> {
      let logout_effect =
        endpoints.post_request_ignore_response_body(
          endpoints.logout(),
          json.null(),
          ApiOnLogoutResponse,
        )
      #(model, logout_effect)
    }
    ApiOnLogoutResponse(r) -> logout(r, model, noop)

    // ### WEBSOCKET ###
    WsWrapper(socket_event) -> handle_socket_event(model, socket_event)

    // ### CHAT ###
    NewConversationMsg(msg) -> handle_new_conversation_msg(model, msg)
    UserOnSendSubmit -> #(model, send_message(model))
    // TODO: 
    ApiChatMessageResponse(_) -> todo
  }
}

fn logout(
  request_result: Result(Nil, rsvp.Error),
  model: app_types.Model,
  noop: #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let login_model = Model(PreLogin, model.global_state)

  case request_result {
    Ok(_) ->
      case model.app_state {
        LoggedIn(LoginState(_, Established(sock), ..)) -> #(
          login_model,
          ws.close(sock),
        )
        LoggedIn(_) -> #(login_model, effect.none())
        PreLogin -> noop
      }

    Error(_) ->
      toast_state.show_toast(
        model,
        toast.create_error_toast("Failed to logout"),
      )
  }
}

fn handle_new_conversation_msg(
  model: Model,
  msg: NewConversationMsg,
) -> #(Model, Effect(Msg)) {
  let assert LoggedIn(login_state) = model.app_state
    as "must be logged in at this point"

  let #(new_conversation, effect) = case msg {
    UserModalOpen -> #(Some(NewConversation([])), search_usernames(""))
    UserModalClose -> #(None, effect.none())
    UserSearchInputChange(v) -> #(
      login_state.new_conversation,
      search_usernames(v),
    )
    ApiSearchResponse(Ok(items)) -> #(
      Some(
        NewConversation(
          list.filter(items, fn(item) { item.id != login_state.session.user_id }),
        ),
      ),
      effect.none(),
    )
    ApiSearchResponse(Error(_)) -> #(
      login_state.new_conversation,
      effect.none(),
    )
    UserConversationPartnerSelect(_) -> #(None, effect.none())
  }

  let #(selected_conversation, conversations, additional_effect) = case msg {
    ApiSearchResponse(Error(_)) -> {
      let toast_effect =
        effect.from(fn(dispatch) {
          dispatch(
            ShowToast(toast.create_error_toast("Failed to search users")),
          )
        })

      #(
        login_state.selected_conversation,
        login_state.conversations,
        toast_effect,
      )
    }
    UserConversationPartnerSelect(dto) -> {
      let next_conversations =
        dict.upsert(login_state.conversations, dto, fn(curr) {
          case curr {
            None -> []
            Some(chat_messages) -> chat_messages
          }
        })

      #(Some(dto), next_conversations, effect.none())
    }
    _ -> #(
      login_state.selected_conversation,
      login_state.conversations,
      effect.none(),
    )
  }

  #(
    Model(
      LoggedIn(
        LoginState(
          ..login_state,
          new_conversation:,
          selected_conversation:,
          conversations:,
        ),
      ),
      model.global_state,
    ),
    effect.batch([effect, additional_effect]),
  )
}

fn send_message(model: Model) -> Effect(Msg) {
  let assert LoggedIn(login_state) = model.app_state
    as "must be logged in at this point"

  let assert Ok(draft) =
    login_state.conversations
    |> dict.to_list
    |> list.find_map(fn(item) {
      let #(user, messages) = item
      case
        option.Some({ user }.id)
        == option.map(login_state.selected_conversation, fn(conv) { conv.id })
      {
        True ->
          list.find(messages, fn(msg) { msg.delivery == shared_chat.Draft })
        False -> Error(Nil)
      }
    })
    as "shouldn't be allowed to send without draft msg"

  endpoints.post_request(
    endpoints.chats(),
    draft |> shared_chat.chat_message_to_json,
    shared_chat.chat_message_decoder(),
    ApiChatMessageResponse,
  )
}

fn search_usernames(value: String) -> Effect(Msg) {
  let json_body =
    value
    |> Username
    |> UsersByUsernameDto
    |> shared_user.users_by_username_dto_to_json

  endpoints.post_request(
    endpoints.search_users(),
    json_body,
    decode.list(shared_user.decode_user_mini_dto()),
    fn(r) { NewConversationMsg(ApiSearchResponse(r)) },
  )
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
            // TODO: reconnect with delay
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
  let LoginState(session, _, new_conv, selected_conversation, conversations) =
    model

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
        ..conversations
        |> dict.to_list
        |> list.sort(fn(left, right) {
          order.break_tie(
            timestamp.compare(
              latest_message_time(left.1),
              latest_message_time(right.1),
            ),
            string.compare({ left.0 }.username.v, { right.0 }.username.v),
          )
        })
        |> list.map(fn(conversation) {
          html.button(
            [
              class("p-4 hover:bg-gray-100 cursor-pointer w-full text-left"),
              event.on_click(
                NewConversationMsg(UserConversationPartnerSelect(conversation.0)),
              ),
            ],
            [
              html.text({ conversation.0 }.username.v),
            ],
          )
        })
      ]),
      // Logout Button
      html.div([class("p-4")], [
        button.view_default_icon_button(
          text: "Logout",
          disabled: False,
          msg: UserOnLogoutClick,
          additional_class: "",
          icon: icons.log_out([class("size-6")]),
        ),
      ]),
    ]),

    // Main Content
    html.div([class("w-2/3 flex flex-col")], [
      // Header
      html.header([class("p-4 border-b border-gray-200 bg-white shadow-sm")], [
        html.h1([class("text-xl font-semibold")], case selected_conversation {
          None -> [
            html.text("Welcome " <> session.username.v <> "!"),
          ]
          Some(dto) -> [
            html.text("Chat with " <> dto.username.v),
          ]
        }),
      ]),

      // Chat messages area
      html.main(
        [class("flex-1 p-4 overflow-y-auto")],
        view_chat_messages(selected_conversation, conversations),
      ),

      // Message input area
      html.footer([class("p-4 bg-white border-t border-gray-200")], [
        html.div([class("flex")], [
          html.input([
            class(
              "w-full border border-gray-300 rounded-l-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 "
              <> "disabled:bg-gray-100 ",
            ),
            attribute.disabled(selected_conversation |> option.is_none),
            placeholder("Message..."),
          ]),

          html.button(
            [
              class(
                "bg-blue-600 text-white font-semibold py-2 px-4 rounded-r-md transition-colors"
                |> button.default_disabled_class
                |> button.default_hovered_class,
              ),
              attribute.disabled(selected_conversation |> option.is_none),
              event.on_click(UserOnSendSubmit),
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

fn view_chat_messages(
  selected_conversation: option.Option(shared_user.UserMiniDto),
  conversations: dict.Dict(
    shared_user.UserMiniDto,
    List(
      shared_chat.ChatMessage(
        shared_user.UserId,
        shared_chat.ChatMessageDelivery,
      ),
    ),
  ),
) -> List(Element(Msg)) {
  case selected_conversation {
    None -> [
      html.p([], [html.text("Select a friend to start chatting...")]),
    ]
    Some(conversation) -> {
      case dict.get(conversations, conversation) {
        Error(_) -> {
          io.print_error(
            "couldn't load conversation with" <> conversation.username.v,
          )
          [
            html.p([attribute.class("")], [html.text("Conversation not found")]),
          ]
        }

        Ok(messages) -> {
          case messages {
            [] -> [
              html.p([class("text-gray-500 text-center")], [
                html.text("No messages yet. Start the conversation!"),
              ]),
            ]
            _ ->
              messages
              |> list.map(view_chat_message)
          }
        }
      }
    }
  }
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
            ]),
            html.div([], [
              case state.suggestions {
                [] ->
                  html.p([class("text-gray-500")], [
                    html.text("Search results will appear here."),
                  ])
                dtos ->
                  html.div(
                    [],
                    list.map(dtos, fn(dto: shared_user.UserMiniDto) {
                      html.button(
                        [
                          class(
                            "flex items-center gap-1 p-4 hover:bg-gray-100 cursor-pointer w-full",
                          ),
                          event.on_click(
                            dto
                            |> UserConversationPartnerSelect
                            |> NewConversationMsg,
                          ),
                        ],
                        [
                          html.text(dto.username.v),
                        ],
                      )
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

fn view_chat_message(message: ClientChatMessage) -> Element(Msg) {
  let is_draft = message.delivery == shared_chat.Draft
  let message_class = case is_draft {
    True -> "bg-yellow-100 border-yellow-200 text-yellow-800"
    False -> "bg-blue-50 border-blue-200"
  }

  html.div([class("mb-3 p-3 rounded-lg border " <> message_class)], [
    html.div([class("flex justify-between items-start mb-1")], [
      html.span([class("font-medium text-sm")], [
        html.text(case is_draft {
          True -> "Draft"
          False -> "You"
        }),
      ]),
      case message.sent_time {
        Some(time) -> {
          let #(_date, time_of_day) =
            timestamp.to_calendar(time, calendar.utc_offset)
          let hours =
            int.to_string(time_of_day.hours) |> string.pad_start(2, "0")
          let minutes =
            int.to_string(time_of_day.minutes) |> string.pad_start(2, "0")
          html.span([class("text-xs text-gray-500")], [
            html.text(hours <> ":" <> minutes),
          ])
        }
        None -> html.span([], [])
      },
    ]),
    html.p([class("text-sm")], [
      html.text(string.join(message.text_content, " ")),
    ]),
  ])
}

fn latest_message_time(messages: List(ClientChatMessage)) -> timestamp.Timestamp {
  messages
  |> list.first
  |> result.map(fn(msg) {
    option.unwrap(msg.sent_time, timestamp.from_unix_seconds(0))
  })
  |> result.unwrap(timestamp.from_unix_seconds(0))
}
