import gleam/bit_array
import gleam/crypto
import gleam/http
import gleam/http/cookie
import gleam/http/response
import gleam/list
import gleam/option
import gleam/result
import wisp.{type Response}

pub fn get_cookie_from_header(
  headers: List(http.Header),
  cookie_name: String,
  security: wisp.Security,
  secret: BitArray,
) -> Result(String, Nil) {
  use value <- result.try(
    headers
    |> list.filter_map(fn(header) {
      let #(name, value) = header
      case name {
        "cookie" -> Ok(cookie.parse(value))
        _ -> Error(Nil)
      }
    })
    |> list.flatten()
    |> list.key_find(cookie_name),
  )

  echo #(value, security)

  //  use value <- result.try(
  case security {
    wisp.PlainText -> Ok(value)
    // bit_array.base64_decode(value)
    wisp.Signed ->
      crypto.verify_signed_message(value, secret)
      |> result.map(bit_array.to_string)
      |> result.flatten
  }
  //)
  //value 
}

pub fn set_cookie_with_domain(
  response: Response,
  name: String,
  value: String,
  max_age: Int,
  _http_only: Bool,
) -> Response {
  let attributes =
    cookie.Attributes(
      max_age: option.Some(max_age),
      domain: option.Some("localhost"),
      // Explicit localhost domain for cross-port access
      path: option.Some("/"),
      secure: False,
      // False for development on localhost
      http_only: False,
      same_site: option.Some(cookie.Lax),
    )

  let cookie_header_value = cookie.set_header(name, value, attributes)

  response.prepend_header(response, "set-cookie", cookie_header_value)
}
