// NOTE: 
// lustre_http cannot handle relative paths like `/api/users` although they would get proxied by lustre dev-tools
// https://codeberg.org/kero/lustre_http/issues/5#issuecomment-6894908
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
