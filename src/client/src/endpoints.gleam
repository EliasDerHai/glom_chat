import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/json.{type Json}
import gleam/option
import lustre/effect.{type Effect}
import rsvp.{type Error}
import util/cookie

// CONSTS ------------------------------------------------------------------------

// NOTE:
// lustre_http cannot handle relative paths like `/api/users` although they would get proxied by lustre dev-tools
// https://codeberg.org/kero/lustre_http/issues/5#issuecomment-6894908

@external(javascript, "./endpoints_ffi.mjs", "getApiUrl")
fn get_api_url() -> String

@external(javascript, "./endpoints_ffi.mjs", "getSocketUrl")
fn get_socket_url() -> String

pub fn me() {
  "auth/me" |> to_req
}

pub fn login() {
  "auth/login" |> to_req
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

pub fn socket_address() {
  get_socket_url()
}

// HELPER ------------------------------------------------------------------------
fn to_req(sub_path: String) -> Request(String) {
  let assert Ok(req) = { get_api_url() <> sub_path } |> request.to()
  req
}

/// the default POST
/// sends json; expects json response
/// kind of: 
/// a -> b -> c -> Effect(c)
pub fn post_request(
  request: Request(a),
  body: Json,
  decoder: Decoder(b),
  effect: fn(Result(b, Error)) -> c,
) -> Effect(c) {
  request
  |> request.set_method(http.Post)
  |> request.set_header("content-type", "application/json")
  |> request.set_header(
    "x-csrf-token",
    "csrf_token" |> cookie.get_cookie |> option.unwrap(""),
  )
  |> request.set_body(body |> json.to_string)
  |> rsvp.send(rsvp.expect_json(decoder, effect))
}

/// the default GET
/// expects json response
/// kind of: 
/// a -> b -> Effect(b)
pub fn get_request(
  request: Request(String),
  decoder: Decoder(b),
  effect: fn(Result(b, Error)) -> c,
) -> Effect(c) {
  request
  |> request.set_method(http.Get)
  |> rsvp.send(rsvp.expect_json(decoder, effect))
}
