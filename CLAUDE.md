# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Gleam-based chat application called "glom_chat" with a full-stack architecture consisting of:

- **Server**: Gleam backend using Wisp web framework, PostgreSQL database, WebSocket support
- **Client**: Gleam frontend using Lustre framework (compiles to JavaScript)

## Architecture

### Server (`src/server/`)
- **Web Framework**: Wisp with Mist HTTP server
- **Database**: PostgreSQL with Pog database driver and Cigogne migrations
- **WebSocket**: Real-time communication support via Mist
- **Auth**: Custom user authentication with password hashing
- **Port**: Runs on port 8000

**Key modules**:
- `app.gleam` - Main server entry point with WebSocket routing
- `app/http_router.gleam` - HTTP request routing and middleware
- `app/domain/user.gleam` - User entity and authentication endpoints
- `app/persist/` - Database connection pooling, SQL queries, and migrations
- `app/websocket.gleam` - WebSocket message handling

### Client (`src/client/`)
- **Frontend Framework**: Lustre (Elm-like architecture for JavaScript)
- **Forms**: Custom form validation system with real-time error display
- **Styling**: Tailwind CSS for UI components
- **State Management**: Model-View-Update pattern with effects

**Key modules**:
- `app.gleam` - Main client entry point and root state management
- `pre_login.gleam` - Login/signup forms with validation
- `form.gleam` - Form field validation utilities

## Development Commands

### Server Development
```bash
# Run server with hot reload (uses watchexec)
./src/server/scripts/run.sh

# Run database migrations
./src/server/scripts/migrate.sh

# Alternative: Direct Gleam commands (from src/server/)
gleam run                    # Start server once
gleam test                   # Run tests
gleam build                  # Build project
gleam check                  # Type check
gleam format                 # Format code
```

### Client Development
```bash
# Run client dev server with hot reload
./src/client/scripts/run.sh

# Alternative: Direct Gleam command (from src/client/)
gleam run -m lustre/dev start    # Start development server
```

### Database Setup
The server requires PostgreSQL running on:
- **Host**: `localhost` (macOS) or WSL-detected IP
- **Port**: 5432
- **Database**: `glom_chat`
- **Credentials**: `postgres:postgres`

## Key Dependencies

### Server
- `wisp` - Web framework and HTTP utilities
- `mist` - HTTP server with WebSocket support
- `pog` - PostgreSQL database driver
- `cigogne` - Database migration tool
- `gleam_json`, `gleam_http` - JSON and HTTP utilities
- `youid` - UUID generation

### Client  
- `lustre` - Frontend framework with virtual DOM
- `lustre_dev_tools` - Development server and hot reload
- `rsvp` - HTTP client for API requests

## Testing

Both projects use `gleeunit` for testing:
```bash
# Run tests
cd src/server && gleam test
cd src/client && gleam test
```

## Database Migrations

Migrations are stored in `src/server/priv/migrations/` and managed by Cigogne:
- Migrations run automatically on server startup
- Use `generate_queries.sh` script for SQL query generation (if present)
- Current schema includes users table with authentication

## WebSocket Communication

The server supports WebSocket connections at `/ws` endpoint for real-time features. WebSocket handling is implemented in `app/websocket.gleam`.

## Build Output

- Server builds to Erlang bytecode
- Client builds to JavaScript (target specified in gleam.toml)
- Build artifacts in respective `build/` directories
