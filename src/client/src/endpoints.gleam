import gleam/dynamic/decode.{type Decoder}
import gleam/http
import gleam/http/request.{type Request}
import gleam/json.{type Json}
import gleam/option
import gleam/result
import lustre/effect.{type Effect}
import rsvp.{type Error}
import util/cookie

// URLS ------------------------------------------------------------------------

fn get_api_url() -> String {
  get_origin() <> "/api/"
}

fn get_socket_url() -> String {
  case get_origin() {
    "https://" <> rest -> "wss://" <> rest <> "/ws"
    "http://" <> rest -> "ws://" <> rest <> "/ws"
    other -> panic as { "didn't expect origin to be: '" <> other <> "'" }
  }
}

@external(javascript, "./location_ffi.mjs", "getOrigin")
fn get_origin() -> String

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

pub fn socket_address() {
  get_socket_url()
}

// HELPER ------------------------------------------------------------------------

fn to_req(sub_path: String) -> Request(String) {
  let url = get_api_url() <> sub_path
  case url |> request.to() {
    Error(_) -> panic as { "failed building request for url: " <> url }
    Ok(r) -> r
  }
}

/// the default POST
/// sends json; expects json response
/// kind of: 
/// a -> b -> c -> Effect(c)
pub fn post_request(
  request: Request(a),
  body: Json,
  decoder: Decoder(b),
  eff: fn(Result(b, Error)) -> c,
) -> Effect(c) {
  request
  |> request.set_method(http.Post)
  |> request.set_header("content-type", "application/json")
  |> request.set_header(
    "x-csrf-token",
    "csrf_token" |> cookie.get_cookie |> option.unwrap(""),
  )
  |> request.set_body(body |> json.to_string)
  |> rsvp.send(rsvp.expect_json(decoder, eff))
}

/// fire and forget POST
/// sends json; response can be anything / nothing
/// only http-status 200 matters
pub fn post_request_ignore_response_body(
  request: Request(a),
  body: Json,
  eff: fn(Result(Nil, Error)) -> c,
) -> Effect(c) {
  request
  |> request.set_method(http.Post)
  |> request.set_header("content-type", "application/json")
  |> request.set_header(
    "x-csrf-token",
    "csrf_token" |> cookie.get_cookie |> option.unwrap(""),
  )
  |> request.set_body(body |> json.to_string)
  |> rsvp.send(
    rsvp.expect_ok_response(fn(r) { r |> result.map(fn(_) { Nil }) |> eff }),
  )
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
