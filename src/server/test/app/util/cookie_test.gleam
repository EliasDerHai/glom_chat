import app/util/cookie.{Cookie}
import gleam/bit_array
import gleam/crypto
import gleam/http.{Https}
import gleam/http/request
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import glisten/socket.{type Socket}
import glisten/transport.{Tcp}
import mist
import mist/internal/http.{Initial} as mhttp
import wisp.{PlainText, Signed}
import wisp/simulate

@external(erlang, "erlang", "make_ref")
fn mock_socket() -> Socket

const cookie_key = "some_key"

const cookie_value = "some_value"

const full_plain_cookie = "some_key=some_value; Max-Age=3600; Path=/; Secure; HttpOnly; SameSite=Lax"

fn get_full_signed_cookie() {
  let encrypted =
    crypto.sign_message(
      "some_value" |> bit_array.from_string,
      secret,
      crypto.Sha256,
    )

  "some_key="
  <> encrypted
  <> "; Max-Age=3600; Path=/; Secure; HttpOnly; SameSite=Lax"
}

const secret_str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

const secret = <<secret_str:utf8>>

// ##############################################################################
// Plaintext
// ##############################################################################

pub fn set_plaintext_cookie_test() {
  // arrange
  let request = wisp.response(200)

  // act
  let actual =
    cookie.set_cookie(request, cookie_key, cookie_value, 3600, True, None)

  // assert
  should.equal(
    Ok(#("set-cookie", full_plain_cookie)),
    list.first(actual.headers),
  )
}

pub fn get_plaintext_cookie_from_wisp_test() {
  // arrange
  let req =
    simulate.request(http.Post, "")
    |> simulate.header("cookie", full_plain_cookie)

  // act 
  let actual = cookie.get_cookie_from_wisp_request(req, cookie_key, PlainText)

  // assert
  should.equal(cookie_value |> Cookie |> Ok, actual)
}

pub fn get_plaintext_cookie_from_mist_test() {
  // arrange
  let req: request.Request(mist.Connection) =
    request.Request(
      method: http.Post,
      headers: [
        #("cookie", full_plain_cookie),
      ],
      body: mhttp.Connection(Initial(<<>>), mock_socket(), transport: Tcp),
      scheme: Https,
      host: "glom.dev",
      port: Some(8080),
      path: "/",
      query: None,
    )

  // act 
  let actual =
    cookie.get_cookie_from_mist_request(req, cookie_key, PlainText, secret)

  // assert
  should.equal(cookie_value |> Cookie |> Ok, actual)
}

// ##############################################################################
// Signed
// ##############################################################################

pub fn set_signed_cookie_test() {
  // arrange
  let request = wisp.response(200)

  // act
  let actual =
    cookie.set_cookie(
      request,
      cookie_key,
      cookie_value,
      3600,
      True,
      Some(#(crypto.Sha256, secret)),
    )

  // assert
  should.equal(
    Ok(#("set-cookie", get_full_signed_cookie())),
    list.first(actual.headers),
  )
}

pub fn get_signed_cookie_from_wisp_test() {
  // arrange
  let req =
    simulate.request(http.Post, "")
    |> simulate.header("cookie", get_full_signed_cookie())
    |> wisp.set_secret_key_base(secret_str)

  // act 
  let actual = cookie.get_cookie_from_wisp_request(req, cookie_key, Signed)

  // assert
  should.equal(cookie_value |> Cookie |> Ok, actual)
}

pub fn get_signed_cookie_from_mist_test() {
  // arrangefull_plain_cookie
  let req: request.Request(mist.Connection) =
    request.Request(
      method: http.Post,
      headers: [
        #("cookie", get_full_signed_cookie()),
      ],
      body: mhttp.Connection(Initial(<<>>), mock_socket(), Tcp),
      scheme: Https,
      host: "glom.dev",
      port: Some(8080),
      path: "/",
      query: None,
    )

  // act 
  let actual =
    cookie.get_cookie_from_mist_request(req, cookie_key, Signed, secret)

  // assert
  should.equal(cookie_value |> Cookie |> Ok, actual)
}
