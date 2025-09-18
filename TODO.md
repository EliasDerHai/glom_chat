# TODO - Glom Chat Development

## Backend

### Core Features
- [ ] Implement real-time chat messaging
- [ ] Add cache for sessions (no db-trip for every request)
- [ ] Add chat room/conversation management
- [ ] Add message history pagination
- [ ] Implement user presence indicators
- [ ] Add typing indicators
- [ ] Implement file upload/sharing

### Security & Auth
- [ ] Implement rate limiting
- [ ] Add input validation and sanitization

## Frontend

### Core Features
- [ ] Complete chat interface implementation
- [ ] Implement real-time message display
- [ ] Add user search and conversation creation

### Production
- [ ] Add proper favicon and PWA manifest
- [ ] Add accessibility improvements (ARIA labels, keyboard navigation)

## Infrastructure

- [ ] Eval if Neon suitable for long term pgo ([see discord thread](https://discord.com/channels/768594524158427167/1417525313591574528))
- [ ] Document Docker development workflow
- [ ] Create local integration tests
- [ ] Add automated tests for API endpoints
- [ ] Set up database seeding for testing
- [ ] Create end-to-end testing framework
- [ ] Set up monitoring and logging


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
