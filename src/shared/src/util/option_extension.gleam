import gleam/option.{type Option}

pub fn to_list(o: Option(a)) -> List(a) {
  case o {
    option.None -> []
    option.Some(elem) -> [elem]
  }
}

pub fn for_each(o: Option(a), consume: fn(a) -> Nil) {
  case o {
    option.None -> Nil
    option.Some(a) -> consume(a)
  }
}
