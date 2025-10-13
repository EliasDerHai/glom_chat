import gleam/http/request.{type Request}

pub fn socket_address() -> String {
  case get_origin() {
    "https://" <> rest -> "wss://" <> rest <> "/ws"
    "http://" <> rest -> "ws://" <> rest <> "/ws"
    other -> panic as { "didn't expect origin to be: '" <> other <> "'" }
  }
}

pub fn me() {
  "auth/me" |> to_req
}

pub fn login() {
  "auth/login" |> to_req
}

pub fn logout() {
  "auth/logout" |> to_req
}

pub fn users() {
  "users" |> to_req
}

pub fn search_users() {
  "users/search" |> to_req
}

pub fn chats() {
  "chats" |> to_req
}

pub fn conversations() {
  "chats/conversations" |> to_req
}

pub fn chat_confirmation() {
  "chats/confirmations" |> to_req
}

// HELPER ------------------------------------------------------------------------

@external(javascript, "./util/location_ffi.mjs", "getOrigin")
fn get_origin() -> String {
  "http://localhost:8000"
}

fn get_api_url() -> String {
  get_origin() <> "/api/"
}

fn to_req(sub_path: String) -> Request(String) {
  let url = get_api_url() <> sub_path
  case url |> request.to() {
    Error(_) -> panic as { "failed building request for url: " <> url }
    Ok(r) -> r
  }
}
