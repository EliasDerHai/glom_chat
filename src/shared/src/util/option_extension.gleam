import gleam/option.{type Option}

pub fn to_list(o: Option(a)) -> List(a) {
  case o {
    option.None -> []
    option.Some(elem) -> [elem]
  }
}
