import gleam/dict.{type Dict}
import gleam/list

pub fn map_keys(in dict: Dict(a, value), with fun: fn(a) -> b) -> Dict(b, value) {
  dict
  |> dict.to_list()
  |> list.map(fn(pair) {
    let #(key, value) = pair
    #(fun(key), value)
  })
  |> dict.from_list()
}
