import gleam/list
import gleam/option.{type Option}
import gleam/string

@external(javascript, "./cookie_ffi.mjs", "get_document_cookie")
fn get_document_cookie() -> String

pub fn get_cookie(name: String) -> Option(String) {
  get_document_cookie()
  |> string.split(";")
  |> list.map(string.trim)
  |> list.filter_map(fn(raw) { string.split_once(raw, "=") })
  |> list.find_map(fn(cookie_pair) {
    let #(key, value) = cookie_pair
    case key == name {
      False -> Error(Nil)
      True -> Ok(value)
    }
  })
  |> option.from_result
}
