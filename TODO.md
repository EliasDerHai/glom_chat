# TODO - Glom Chat Development

## Backend

### Environment Configuration
- [ ] Replace hardcoded URLs, ports, etc. with environment variables
- [ ] Create `.env` file for each environments
- [ ] Test configuration with different environments

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
- [ ] Implement WebSocket connection management
- [ ] Add responsive design for mobile devices
- [ ] Implement proper error handling and loading states

### Production Readiness
- [ ] Configure production API endpoints (environment-based)
- [ ] Optimize bundle size and performance
- [ ] Add proper favicon and PWA manifest
- [ ] Implement proper routing and navigation
- [ ] Add accessibility improvements (ARIA labels, keyboard navigation)

## Infrastructure

### Phase 2: Local Docker Setup
- [ ] Create `docker-compose.yml` with PostgreSQL service
- [ ] Update Docker networking to use compose
- [ ] Create environment-specific Docker configurations
- [ ] Test Docker setup with local PostgreSQL
- [ ] Document Docker development workflow

### Phase 3: Testing Strategy
- [ ] Create local integration test script (`scripts/test-integration.sh`)
- [ ] Set up lightweight GitHub Action for PR builds
- [ ] Add automated tests for API endpoints
- [ ] Set up database seeding for testing
- [ ] Create end-to-end testing framework

### Phase 4: Production Deployment
- [ ] Configure CORS for GitHub Pages origin
- [ ] Set up secrets management for production
- [ ] Create production database migration strategy
- [ ] Set up Neon PostgreSQL database
- [ ] Configure Fly.io deployment
- [ ] Set up GitHub Pages deployment for frontend
- [ ] Configure custom domain and SSL
- [ ] Set up monitoring and logging
- [ ] Create backup and disaster recovery plan

### CI/CD Pipeline
- [ ] Create GitHub Actions workflow for backend deployment
- [ ] Create GitHub Actions workflow for frontend deployment
- [ ] Set up automated database migrations

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
- [x] Environment configuration foundation
