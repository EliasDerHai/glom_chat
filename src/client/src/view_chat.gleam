import app_types.{
  type Conversation, type LoginState, type Msg, type NewConversation,
  Conversation, LoginState, NewConversationMsg, UserConversationPartnerSelect,
  UserModalClose, UserModalOpen, UserOnLogoutClick, UserOnMessageChange,
  UserOnSendSubmit, UserSearchInputChange,
}
import conversation
import gleam/dict
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared_chat.{type ClientChatMessage}
import shared_user.{type UserId, type UserMiniDto, type Username}
import util/button
import util/icons
import util/option_extension
import util/time_util

pub fn view_chat(model: LoginState) -> Element(Msg) {
  let LoginState(session, _, new_conv, selected_conversation, conversations) =
    model

  let draft_text = case selected_conversation {
    None -> ""
    Some(user) ->
      case dict.get(conversations, user.id) {
        Error(_) -> ""
        Ok(conversation) -> conversation.draft_message_text
      }
  }

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
          attribute.placeholder("Search chats..."),
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
        |> conversation.sort_conversations
        |> list.map(fn(key_value) {
          html.button(
            [
              class("p-4 hover:bg-gray-100 cursor-pointer w-full text-left"),
              event.on_click(
                NewConversationMsg(
                  UserConversationPartnerSelect(shared_user.UserMiniDto(
                    key_value.0,
                    { key_value.1 }.conversation_partner,
                  )),
                ),
              ),
            ],
            [
              html.text({ key_value.1 }.conversation_partner.v),
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
        view_chat_messages(
          selected_conversation,
          conversations,
          session.user_id,
        ),
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
            attribute.value(draft_text),
            attribute.placeholder("Message..."),
            event.on_change(UserOnMessageChange),
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
  selected_conversation: option.Option(UserMiniDto(UserId)),
  conversations: dict.Dict(UserId, Conversation),
  self: UserId,
) -> List(Element(Msg)) {
  case selected_conversation {
    None -> [
      html.p([], [html.text("Select a friend to start chatting...")]),
    ]
    Some(dto) -> {
      case dict.get(conversations, dto.id) {
        Error(_) -> {
          io.print_error("couldn't load conversation with" <> dto.username.v)
          [
            html.p([attribute.class("")], [html.text("Conversation not found")]),
          ]
        }

        Ok(Conversation(messages, _, _)) -> {
          case messages {
            [] -> [
              html.p([class("text-gray-500 text-center")], [
                html.text("No messages yet. Start the conversation!"),
              ]),
            ]
            _ ->
              messages
              |> conversation.sort_messages
              |> list.map(fn(message) {
                view_chat_message(message, self, dto.username)
              })
          }
        }
      }
    }
  }
}

fn view_chat_message(
  message: ClientChatMessage,
  self: UserId,
  other: Username,
) -> Element(Msg) {
  let self_is_sender = message.sender == self

  let message_class = case self_is_sender {
    False -> "bg-gray-50 border-gray-200"
    True -> "bg-blue-50 border-blue-200"
  }

  html.div([class("mb-3 p-3 rounded-lg border " <> message_class)], [
    html.div([class("flex justify-between items-start mb-1")], [
      html.span([class("font-medium text-sm")], [
        html.text(case self_is_sender {
          True -> "You"
          False -> other.v
        }),
      ]),
      html.span(
        [class("text-xs text-gray-500")],
        message.sent_time
          |> option.map(time_util.to_hhmm)
          |> option.map(html.text)
          |> option_extension.to_list,
      ),
    ]),
    html.p([class("text-sm")], [
      html.text(string.join(message.text_content, " ")),
    ]),
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
              attribute.placeholder("Search user..."),
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
                    list.map(dtos, fn(dto: UserMiniDto(UserId)) {
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
