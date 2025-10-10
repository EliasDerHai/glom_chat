import app_types.{
  type Conversation, type LoginState, type Model, type Msg,
  type NewConversationMsg, type SocketState, ApiChatMessageConfirmationResponse,
  ApiChatMessageFetchResponse as ApiChatConversationsFetchResponse,
  ApiChatMessageSendResponse, ApiOnLogoutResponse, ApiSearchResponse,
  CheckedAuth, Conversation, Established, GlobalState, IsTypingExpired, LoggedIn,
  LoginState, LoginSuccess, Model, NewConversation, NewConversationMsg, Pending,
  PreLogin, RemoveToast, ShowToast, UserConversationPartnerSelect,
  UserModalClose, UserModalOpen, UserOnLogoutClick, UserOnMessageChange,
  UserOnSendSubmit, UserSearchInputChange, WsWrapper,
}
import chat/shared_chat.{type ClientChatMessage, ChatMessage, Sent}
import chat/shared_chat_confirmation.{type ChatConfirmation, ChatConfirmation}
import chat/shared_chat_conversation.{
  type ChatConversationDto, ChatConversationDto,
}
import chat/shared_chat_creation_dto.{ChatMessageCreationDto}
import conversation
import endpoints
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/set
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre_websocket as ws
import pre_login
import rsvp.{type Error}
import shared_session
import shared_user.{type UserId, type UserMiniDto, Username, UsersByUsernameDto}
import socket_message/shared_client_to_server
import socket_message/shared_server_to_client.{
  IsTyping, MessageConfirmation, NewMessage, OnlineHasChanged,
}
import util/time_util
import util/toast
import util/toast_state
import view_chat

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
        LoggedIn(
          LoginState(
            session_dto,
            Pending(timestamp.system_time()),
            None,
            None,
            dict.new(),
            set.new(),
            [],
          ),
        ),
        model.global_state,
      ),
      effect.batch([
        ws.init(endpoints.socket_address(), WsWrapper),
        fetch_conversations(),
      ]),
    )
  }

  let logout = fn(result: Result(Nil, Error)) -> #(Model, Effect(Msg)) {
    case result {
      Ok(_) ->
        case model.app_state {
          // socket automatically closed on server side as part of logout
          LoggedIn(_) -> #(Model(PreLogin, model.global_state), effect.none())
          PreLogin -> noop
        }

      Error(_) ->
        toast_state.show_toast(
          model,
          toast.create_error_toast("Failed to logout"),
        )
    }
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
    ApiOnLogoutResponse(r) -> logout(r)

    // ### WEBSOCKET ###
    WsWrapper(socket_event) -> handle_socket_event(model, socket_event)
    IsTypingExpired(id) -> remove_is_typing(model, id)

    // ### CHAT ###
    NewConversationMsg(msg) -> handle_new_conversation_msg(model, msg)
    UserOnMessageChange(text) ->
      update_draft_message_and_notify_typing(model, text)
    UserOnSendSubmit -> #(model, send_message(model))
    ApiChatMessageSendResponse(r) ->
      case r {
        Error(_) ->
          toast_state.show_toast(
            model,
            toast.create_error_toast("Couldn't send message..."),
          )
        Ok(msg) -> handle_api_chat_message_send_response(model, msg)
      }
    ApiChatConversationsFetchResponse(r) -> {
      case r {
        Error(_) ->
          toast_state.show_toast(
            model,
            toast.create_error_toast("Failed to load conversations..."),
          )
        Ok(dto) -> handle_chat_conversation_fetch_response(model, dto)
      }
    }
    ApiChatMessageConfirmationResponse(r) ->
      case r {
        Error(_) -> noop
        Ok(confirmation) -> handle_message_confimation(model, confirmation)
      }
  }
}

fn remove_is_typing(model: Model, id: Int) -> #(Model, Effect(Msg)) {
  let model = case model.app_state {
    LoggedIn(login_state) -> {
      let typing =
        login_state.typing |> list.filter(fn(tuple) { tuple.0 != id })

      Model(LoggedIn(LoginState(..login_state, typing:)), model.global_state)
    }
    _ -> model
  }

  #(model, effect.none())
}

fn update_draft_message_and_notify_typing(
  model: Model,
  text: String,
) -> #(Model, Effect(Msg)) {
  let assert LoggedIn(login_state) = model.app_state
    as "must be logged in at this point"
  let assert Some(selected_conversation) = login_state.selected_conversation
    as "conversation must be selected at this point"

  let conversations =
    dict.upsert(login_state.conversations, selected_conversation.id, fn(curr) {
      case curr {
        None -> panic as "conversation doesn't exist"
        Some(conversation) ->
          Conversation(..conversation, draft_message_text: text)
      }
    })

  let login_state = LoginState(..login_state, conversations:)

  let effect = case login_state.web_socket {
    Established(socket) -> {
      let typer = login_state.session.user_id
      let receiver = selected_conversation.id
      let message = shared_client_to_server.IsTyping(typer:, receiver:)
      let body = shared_client_to_server.to_json(message) |> json.to_string

      socket |> ws.send(body)
    }
    Pending(_) -> effect.none()
  }

  #(Model(LoggedIn(login_state), model.global_state), effect)
}

fn fetch_conversations() -> Effect(Msg) {
  endpoints.get_request(
    endpoints.conversations(),
    shared_chat_conversation.chat_conversation_dto_decoder(),
    ApiChatConversationsFetchResponse,
  )
}

fn handle_api_chat_message_send_response(model: Model, msg: ClientChatMessage) {
  let app_state = case model.app_state {
    LoggedIn(l) -> {
      let conversations =
        l.conversations
        |> dict.upsert(msg.receiver, fn(curr) {
          let assert Some(conversation) = curr
            as { "Can't find conversation " <> msg.receiver.v }

          Conversation(
            list.append(conversation.messages, [msg]),
            conversation.conversation_partner,
            "",
          )
        })

      LoggedIn(LoginState(..l, conversations:))
    }
    PreLogin -> model.app_state
  }

  #(Model(app_state, model.global_state), fetch_conversations())
}

fn handle_chat_conversation_fetch_response(
  model: Model,
  dto: ChatConversationDto,
) -> #(Model, Effect(Msg)) {
  let ChatConversationDto(messages, self, others) = dto
  let assert LoggedIn(login_state) = model.app_state
    as "must be logged in at this point"
  let assert Ok(conversation_partner) = others |> list.first
    as "others must be non-empty"

  let conversations =
    messages
    |> list.group(fn(item) {
      case item.sender == self {
        False -> item.sender
        True -> item.receiver
      }
    })
    |> dict.map_values(fn(user_id, messages) {
      let conversation_partner = case
        others |> list.find(fn(item) { item.id == user_id })
      {
        Ok(dto) -> dto.username
        Error(_) ->
          panic as { "couldn't find conversation partner " <> user_id.v }
      }

      Conversation(messages, conversation_partner, "")
    })

  let selected_conversation =
    conversations
    |> conversation.sort_conversations
    |> list.first
    |> option.from_result
    |> option.map(fn(tuple) {
      let #(user_id, _) = tuple
      let assert Ok(dto) = others |> list.find(fn(item) { item.id == user_id })
      dto
    })

  let model =
    Model(
      LoggedIn(
        LoginState(..login_state, selected_conversation:, conversations:),
      ),
      model.global_state,
    )

  let effects = [
    // confirm 'delivered' of messages (based on all fetched messages)
    ChatConfirmation(
      messages
        |> list.filter_map(fn(m) {
          case m.delivery == Sent {
            False -> Error(Nil)
            True -> Ok(m.id)
          }
        }),
      shared_chat_confirmation.Delivered,
    )
      |> send_chat_confirmation(login_state.web_socket),
    // confirm 'read' of messages (based on selected conversation - which should be rendered subsequently)
    confirm_read_messages_on_conversation_select(
      conversations,
      conversation_partner.id,
      login_state.session.user_id,
      login_state.web_socket,
    ),
  ]

  #(model, effect.batch(effects))
}

fn send_chat_confirmation(
  confirmation: ChatConfirmation,
  socket_state: SocketState,
) -> Effect(Msg) {
  use <- bool.guard(confirmation.message_ids |> list.is_empty, effect.none())

  let confirm_body =
    confirmation
    |> shared_client_to_server.MessageConfirmation
    |> shared_client_to_server.to_json

  case socket_state {
    Established(socket:) -> socket |> ws.send(confirm_body |> json.to_string)
    Pending(_) ->
      endpoints.post_request(
        endpoints.chat_confirmation(),
        confirm_body,
        shared_chat_confirmation.chat_confirmation_decoder(),
        ApiChatMessageConfirmationResponse,
      )
  }
}

fn handle_new_conversation_msg(
  model: Model,
  msg: NewConversationMsg,
) -> #(Model, Effect(Msg)) {
  let assert LoggedIn(login_state) = model.app_state
    as "must be logged in at this point"

  case msg {
    UserModalOpen -> handle_modal_open(model, login_state)
    UserModalClose -> handle_modal_close(model, login_state)
    UserSearchInputChange(v) -> handle_search_input(model, v)
    ApiSearchResponse(res) -> handle_search(model, login_state, res)
    UserConversationPartnerSelect(dto) -> handle_select(model, login_state, dto)
  }
}

fn handle_modal_open(
  model: Model,
  login_state: LoginState,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      LoggedIn(
        LoginState(..login_state, new_conversation: Some(NewConversation([]))),
      ),
      model.global_state,
    ),
    search_usernames(""),
  )
}

fn handle_modal_close(
  model: Model,
  login_state: LoginState,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      LoggedIn(LoginState(..login_state, new_conversation: None)),
      model.global_state,
    ),
    effect.none(),
  )
}

fn handle_search_input(model: Model, value: String) -> #(Model, Effect(Msg)) {
  #(model, search_usernames(value))
}

fn handle_search(
  model: Model,
  login_state: LoginState,
  res: Result(List(UserMiniDto(UserId)), Error),
) -> #(Model, Effect(Msg)) {
  use <- bool.lazy_guard(result.is_error(res), fn() {
    let toast_effect =
      effect.from(fn(dispatch) {
        dispatch(ShowToast(toast.create_error_toast("Failed to search users")))
      })

    #(model, toast_effect)
  })

  let assert Ok(items) = res

  let filtered_items =
    list.filter(items, fn(item) { item.id != login_state.session.user_id })

  #(
    Model(
      LoggedIn(
        LoginState(
          ..login_state,
          new_conversation: Some(NewConversation(filtered_items)),
        ),
      ),
      model.global_state,
    ),
    effect.none(),
  )
}

fn handle_select(
  model: Model,
  login_state: LoginState,
  dto: UserMiniDto(UserId),
) -> #(Model, Effect(Msg)) {
  let conversations =
    dict.upsert(login_state.conversations, dto.id, fn(curr) {
      case curr {
        None -> Conversation([], dto.username, "")
        Some(c) -> c
      }
    })

  let model =
    Model(
      LoggedIn(
        LoginState(
          ..login_state,
          new_conversation: None,
          selected_conversation: Some(dto),
          conversations: conversations,
        ),
      ),
      model.global_state,
    )

  let effect =
    confirm_read_messages_on_conversation_select(
      conversations,
      dto.id,
      login_state.session.user_id,
      login_state.web_socket,
    )

  #(model, effect)
}

fn confirm_read_messages_on_conversation_select(
  conversations: Dict(UserId, Conversation),
  conversation_partner: UserId,
  self: UserId,
  socket_state: SocketState,
) {
  let unread_messages =
    conversations
    |> dict.get(conversation_partner)
    |> result.map(fn(conv) { conv.messages })
    |> result.unwrap([])
    |> list.filter_map(fn(msg) {
      let match = msg.receiver == self && msg.delivery != shared_chat.Read
      case match {
        False -> Error(Nil)
        True -> Ok(msg.id)
      }
    })

  ChatConfirmation(unread_messages, shared_chat_confirmation.Read)
  |> send_chat_confirmation(socket_state)
}

fn send_message(model: Model) -> Effect(Msg) {
  let assert LoggedIn(login_state) = model.app_state
    as "must be logged in at this point"
  let assert Some(selected_conversation) = login_state.selected_conversation
    as "conversation must be selected at this point"

  let draft_text = case
    dict.get(login_state.conversations, selected_conversation.id)
  {
    Error(_) -> panic as "conversation doesn't exist"
    Ok(conversation) -> conversation.draft_message_text
  }

  let dto =
    ChatMessageCreationDto(
      receiver: selected_conversation.id,
      text_content: draft_text |> string.split("\n"),
    )

  endpoints.post_request(
    endpoints.chats(),
    dto |> shared_chat_creation_dto.to_json,
    shared_chat.chat_message_decoder(),
    ApiChatMessageSendResponse,
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

      let parsed_message =
        json.parse(message, shared_server_to_client.decoder())

      case parsed_message {
        Error(e) -> {
          io.println_error(
            "Failed to read socket_message: " <> string.inspect(e),
          )
          #(model, effect.none())
        }
        Ok(socket_message) -> {
          case socket_message {
            IsTyping(user) -> {
              let assert LoggedIn(login_state) = model.app_state
                as "must be logged in at this point"

              let tuple = #(time_util.millis_now(), user)
              let typing = login_state.typing |> list.append([tuple])

              let timeout_effect =
                effect.from(fn(dispatch) {
                  time_util.set_timeout(
                    fn() { dispatch(IsTypingExpired(tuple.0)) },
                    duration.seconds(2),
                  )
                })

              #(
                Model(
                  LoggedIn(LoginState(..login_state, typing:)),
                  model.global_state,
                ),
                timeout_effect,
              )
            }

            NewMessage(message:) -> {
              let assert LoggedIn(login_state) = model.app_state
                as "must be logged in at this point"

              case login_state.conversations |> dict.get(message.sender) {
                // TODO: conversations |> dict.insert(message.sender, todo) <- we could avoid the http if we knew the username
                Error(_) -> #(model, fetch_conversations())
                Ok(_) -> {
                  let conversations =
                    login_state.conversations
                    |> dict.upsert(message.sender, fn(existing) {
                      let assert Some(conversation) = existing
                        as "already checked"
                      Conversation(
                        conversation.messages |> list.append([message]),
                        conversation.conversation_partner,
                        conversation.draft_message_text,
                      )
                    })

                  #(
                    Model(
                      LoggedIn(LoginState(..login_state, conversations:)),
                      model.global_state,
                    ),
                    effect.none(),
                  )
                }
              }
            }

            OnlineHasChanged(online:) -> {
              let assert LoggedIn(login_state) = model.app_state
                as "must be logged in at this point"
              let online = online |> set.from_list

              #(
                Model(
                  LoggedIn(LoginState(..login_state, online:)),
                  model.global_state,
                ),
                effect.none(),
              )
            }

            MessageConfirmation(confirmation:) ->
              handle_message_confimation(model, confirmation)
          }
        }
      }
    }
    ws.OnClose(close_reason) -> {
      io.println("WebSocket closed: " <> string.inspect(close_reason))
      case model.app_state {
        LoggedIn(login_state) -> {
          let updated_login_state =
            LoginState(
              ..login_state,
              web_socket: Pending(timestamp.system_time()),
              // reset online-status for all - will be retransmitted after reconnect
              // otherwise we would always show online-status as of disconnect
              online: set.new(),
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

fn handle_message_confimation(
  model: Model,
  confirmation: ChatConfirmation,
) -> #(Model, Effect(Msg)) {
  let assert LoggedIn(login_state) = model.app_state
    as "must be logged in at this point"

  let conversations =
    login_state.conversations
    |> dict.map_values(fn(_, conversation) {
      let messages =
        conversation.messages
        |> list.map(fn(msg) {
          case confirmation.message_ids |> list.contains(msg.id) {
            False -> msg
            True ->
              ChatMessage(
                ..msg,
                delivery: confirmation.confirm
                  |> shared_chat_confirmation.to_delivery,
              )
          }
        })
      Conversation(..conversation, messages:)
    })

  #(
    Model(
      LoggedIn(LoginState(..login_state, conversations:)),
      model.global_state,
    ),
    effect.none(),
  )
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let toasts = toast_state.toast_incl_socket_disconnet(model)

  html.div([], [
    // Main content based on app state
    case model.app_state {
      LoggedIn(login_state) -> view_chat.view_chat(login_state)

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
