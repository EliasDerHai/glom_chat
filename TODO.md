# TODO - Glom Chat Development


## Code & Impl

### Core Features
- [ ] Properly handle "message read/unread"
- [ ] Add message history pagination
- [ ] Add typing indicators
- [ ] Add media attachments
    - probably [Cloudflare R2](https://www.cloudflare.com/en-gb/developer-platform/products/r2/)
- [ ] Add cache for sessions (no db-trip for every request)
- [ ] Add chat room/conversation management
- [ ] Add more friendlist (currently no "blocked", no "invisible users")
- [ ] Add voice message (record, send, receive, play)
- [ ] Add PWA manifest

### UI
- [ ] Show unread message badge
- [ ] Add accessibility improvements (keyboard navigation)
- [ ] Make Sidebar width draggable

### Security & Auth
- [ ] Add rate limiting
- [ ] Add input validation and sanitization


## Infrastructure

- [ ] Deploy via gcp (burn 300$ free creds till christmas XD)
- [ ] Eval if Neon suitable for long term pgo (see [discord thread](https://discord.com/channels/768594524158427167/1417525313591574528))
        - Db alternatives
            - Supabase
            - Prism
- [ ] Add integration tests
- [ ] Add e2e tests
- [ ] Tune monitoring and logging


## Architecture

- [ ] Feature-Based Structure for Client (`src/client/src/`)
    - each domain scoped subdir has *_types.gleam *_update.gleam *_view.gleam (few exceptions) -> high Locality of Behavior 
```
src/
├── app.gleam              # Minimal - just main(), init, top-level update router
├── app_types.gleam        # Only core types: Model, Msg (keep top-level enums)
│
├── features/
│   ├── auth/
│   │   ├── auth_types.gleam       # SessionDto, auth-specific state
│   │   ├── auth_update.gleam      # handle_login, handle_logout, check_auth
│   │   └── auth_view.gleam        # Move pre_login here
│   │
│   ├── chat/
│   │   ├── chat_types.gleam       # Conversation, Message types
│   │   ├── chat_update.gleam      # handle_send_message, handle_receive_message
│   │   ├── chat_view.gleam        # view_chat, view_chat_messages
│   │   └── chat_helpers.gleam     # Merge conversation.gleam here
│   │
│   ├── conversations/
│   │   ├── conversations_types.gleam  # NewConversation
│   │   ├── conversations_update.gleam # All handle_* for new conversation modal
│   │   └── conversations_view.gleam   # view_new_conversation modal
│   │
│   └── websocket/
│       ├── websocket_types.gleam      # SocketState
│       └── websocket_update.gleam     # handle_socket_event, handle_typing
│
├── shared/
│   ├── endpoints.gleam    # Keep as-is
│   └── toast/             # Move toast logic here
│       ├── toast_types.gleam
│       ├── toast_state.gleam
│       └── toast_view.gleam
│
└── util/                  # Keep as-is
```


## Completed

- [x] Basic user authentication (login/signup)
- [x] Session management with cookies
- [x] PostgreSQL database setup with migrations
- [x] WebSocket infrastructure setup
- [x] User search functionality with fuzzy matching
- [x] CSRF token implementation
- [x] Docker build configuration
- [x] Lustre-dev-tools proxy setup
- [x] Cookie handling for both HTTP and WebSocket contexts
- [x] Create `docker-compose.yml` with PostgreSQL service
- [x] Create environment-specific Docker configurations
- [x] Test Docker setup with local PostgreSQL
- [x] Update Docker networking to use compose
- [x] Environment configuration foundation
- [x] Configure production API endpoints (environment-based)
- [x] Optimize bundle size and performance
~~[ ] Implement proper routing and navigation~~
- [x] Implement WebSocket connection management
- [x] Replace hardcoded URLs, ports, etc. with environment variables
~~[ ] Create `.env` file for each environments~~
~~[ ] Configure custom domain and SSL~~
~~[ ] Set up GitHub Pages deployment for frontend~~
- [x] Configure Fly.io deployment
- [x] Set up Neon PostgreSQL database
~~[ ] Configure CORS for GitHub Pages origin~~
- [x] Set up secrets management for production
- [x] Create GitHub Actions workflow for backend deployment
- [x] Create GitHub Actions workflow for frontend deployment
- [x] **CI/CD Pipeline**
- [x] Set up automated database migrations
- [x] Implement real-time chat messaging
- [x] Implement real-time message display
- [x] Add user search and conversation creation
- [x] Add favicon
- [x] Add user online presence indicators
