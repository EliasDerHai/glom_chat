// is being deprecated in stdlib for whatever fucking reason
pub fn unwrap_both(result: Result(a, a)) -> a {
  case result {
    Ok(a) -> a
    Error(a) -> a
  }
}
