pub fn map(tuple: #(a, b), mapping: fn(a, b) -> c) {
  mapping(tuple.0, tuple.1)
}
