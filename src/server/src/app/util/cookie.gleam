import app/util/mist_request
import gleam/bit_array
import gleam/crypto
import gleam/http.{type Header}
import gleam/http/cookie
import gleam/http/response
import gleam/list
import gleam/option.{type Option}
import gleam/result
import wisp.{type Request, type Response, type Security}

pub type Cookie {
  Cookie(v: String)
}

pub fn set_cookie(
  response: Response,
  name: String,
  value: String,
  max_age: Int,
  http_only: Bool,
  hasher: Option(#(crypto.HashAlgorithm, BitArray)),
) -> Response {
  let attributes =
    cookie.Attributes(
      max_age: option.Some(max_age),
      domain: option.None,
      path: option.Some("/"),
      // still fine on localhost
      secure: True,
      http_only: http_only,
      same_site: option.Some(cookie.Lax),
    )

  let value = case hasher {
    option.None -> value
    option.Some(#(algorithm, secret)) ->
      value
      |> bit_array.from_string
      |> crypto.sign_message(secret, algorithm)
  }

  response
  |> response.prepend_header(
    "set-cookie",
    cookie.set_header(name, value, attributes),
  )
}

fn get_cookie_from_headers(
  headers: List(Header),
  cookie_name: String,
  security: Security,
  secret: BitArray,
) -> Result(Cookie, Nil) {
  use value <- result.try(
    headers
    |> list.filter_map(fn(header) {
      case header {
        #("cookie", value) -> cookie.parse(value) |> Ok
        _ -> Error(Nil)
      }
    })
    |> list.flatten()
    |> list.key_find(cookie_name),
  )

  case security {
    wisp.PlainText -> value |> Cookie |> Ok
    wisp.Signed ->
      crypto.verify_signed_message(value, secret)
      |> result.map(bit_array.to_string)
      |> result.flatten
      |> result.map(Cookie)
  }
}

// TODO: 
// remove workaround once websockets are implemented in wisp
// see: https://github.com/gleam-wisp/wisp/issues/10

// For wisp requests (HTTP)
pub fn get_cookie_from_wisp_request(
  request: Request,
  cookie_name: String,
  security: Security,
) -> Result(Cookie, Nil) {
  let secret = <<wisp.get_secret_key_base(request):utf8>>
  get_cookie_from_headers(request.headers, cookie_name, security, secret)
}

// For mist requests (WebSocket)
pub fn get_cookie_from_mist_request(
  request: mist_request.MistRequest,
  cookie_name: String,
  security: Security,
  secret: BitArray,
) -> Result(Cookie, Nil) {
  get_cookie_from_headers(request.headers, cookie_name, security, secret)
}
