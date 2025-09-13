// NOTE:
// Using Vite proxy - requests to /api/* get forwarded to backend
// This works because Vite handles the proxy correctly

// const api = "http://localhost:8000/"
const api = "http://localhost:1234/api/"

pub fn users() {
  api <> "users"
}

pub fn search_users() {
  api <> "users/search"
}

pub fn me() {
  api <> "auth/me"
}

pub fn login() {
  api <> "auth/login"
}

// TODO: configurable? can we proxy this also?
pub fn socket_address() {
  "ws://localhost:8000/ws"
}
