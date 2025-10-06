# TODO - Glom Chat Development

## Code & Impl

### Core Features
- [ ] Add message history pagination
- [ ] Add user online presence indicators
- [ ] Add typing indicators
- [ ] Add image posting
- [ ] Add cache for sessions (no db-trip for every request)
- [ ] Add chat room/conversation management
- [ ] Add more friendlist (currently no "blocked", no "invisible users")
- [ ] Add voice message (record, send, receive, play)

### UI
- [ ] Add accessibility improvements (keyboard navigation)
- [ ] Make Sidebar width draggable

### Security & Auth
- [ ] Add rate limiting
- [ ] Add input validation and sanitization

### Production
- [ ] Add PWA manifest

## Infrastructure

- [ ] Deploy via gcp (burn 300$ free creds till christmas XD)
- [ ] Eval if Neon suitable for long term pgo ([see discord thread](https://discord.com/channels/768594524158427167/1417525313591574528))
        - Db alternatives 
            - Supabase
            - Prism
- [ ] Add local integration tests
- [ ] Add automated tests for API endpoints
- [ ] Add end-to-end testing framework
- [ ] Tune monitoring and logging

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
- [x] Add proper favicon
