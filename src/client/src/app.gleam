import app_types.{
  type Model, type Msg, type NewConversationMsg,
  ApiChatMessageFetchResponse as ApiChatConversationsFetchResponse,
  ApiChatMessageSendResponse, ApiOnLogoutResponse, ApiSearchResponse,
  CheckedAuth, Conversation, Established, GlobalState, LoggedIn, LoginState,
  LoginSuccess, Model, NewConversation, NewConversationMsg, Pending, PreLogin,
  RemoveToast, ShowToast, UserConversationPartnerSelect, UserModalClose,
  UserModalOpen, UserOnLogoutClick, UserOnMessageChange, UserOnSendSubmit,
  UserSearchInputChange, WsWrapper,
}
import conversation
import endpoints
import gleam/dict
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/set
import gleam/string
import gleam/time/timestamp
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre_websocket as ws
import pre_login
import rsvp.{type Error}
import shared_chat.{ChatMessage}
import shared_chat_conversation.{type ChatConversationDto, ChatConversationDto}
import shared_session
import shared_user.{Username, UsersByUsernameDto}
import socket_message/shared_client_to_server
import socket_message/shared_server_to_client.{
  IsTyping, NewMessage, OnlineHasChanged,
}
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
        LoggedIn(LoginState(
          session_dto,
          Pending(timestamp.system_time()),
          None,
          None,
          dict.new(),
          set.new(),
        )),
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
  }
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

fn handle_api_chat_message_send_response(
  model: Model,
  msg: shared_chat.ClientChatMessage,
) {
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

  let app_state = case model.app_state {
    LoggedIn(l) ->
      LoggedIn(LoginState(..l, selected_conversation:, conversations:))
    PreLogin -> model.app_state
  }

  #(Model(app_state, model.global_state), effect.none())
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

  let #(selected_conversation, conversations, additional_effect) = {
    case msg {
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
        let conversations =
          dict.upsert(login_state.conversations, dto.id, fn(curr) {
            case curr {
              None -> Conversation([], dto.username, "")
              Some(c) -> c
            }
          })

        #(Some(dto), conversations, effect.none())
      }
      _ -> #(
        login_state.selected_conversation,
        login_state.conversations,
        effect.none(),
      )
    }
  }

  #(
    Model(
      LoggedIn(
        LoginState(
          ..login_state,
          conversations:,
          new_conversation:,
          selected_conversation:,
        ),
      ),
      model.global_state,
    ),
    effect.batch([effect, additional_effect]),
  )
}

fn send_message(model: Model) -> Effect(Msg) {
  let assert LoggedIn(LoginState(
    session:,
    web_socket: _,
    new_conversation: _,
    selected_conversation: Some(selected_conversation),
    conversations:,
    online: _,
  )) = model.app_state
    as "must be logged in & conversation selected at this point"

  let draft_text = case dict.get(conversations, selected_conversation.id) {
    Error(_) -> panic as "conversation doesn't exist"
    Ok(conversation) -> conversation.draft_message_text
  }

  let draft_message: shared_chat.ClientChatMessage =
    ChatMessage(
      sender: session.user_id,
      receiver: selected_conversation.id,
      delivery: shared_chat.Sending,
      sent_time: None,
      text_content: draft_text |> string.split("\n"),
    )

  endpoints.post_request(
    endpoints.chats(),
    draft_message |> shared_chat.chat_message_to_json,
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
              echo user
              #(model, effect.none())
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
