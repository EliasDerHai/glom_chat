import gleam/float
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}

@external(javascript, "./timeout.ffi.js", "setTimeout")
pub fn set_timeout_from_ms(callback: fn() -> Nil, milliseconds: Int) -> Nil

pub fn set_timeout(callback: fn() -> Nil, duration: Duration) -> Nil {
  set_timeout_from_ms(callback, duration |> duration_to_millis)
}

pub fn duration_to_millis(duration: Duration) {
  float.round(duration.to_seconds(duration) *. 1000.0)
}

pub fn timestamp_to_millis(timestamp: Timestamp) {
  float.round(timestamp.to_unix_seconds(timestamp) *. 1000.0)
}

pub fn millis_now() -> Int {
  timestamp.system_time() |> timestamp_to_millis
}
