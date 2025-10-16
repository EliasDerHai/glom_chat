import gleam/int
import gleam/string
import gleam/time/calendar
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}
import util/time

@external(javascript, "./timeout.ffi.js", "setTimeout")
pub fn set_timeout_from_ms(callback: fn() -> Nil, milliseconds: Int) -> Nil

pub fn set_timeout(callback: fn() -> Nil, duration: Duration) -> Nil {
  set_timeout_from_ms(callback, duration |> time.duration_to_millis)
}

/// t must be UTC time - will be converted to local-time
pub fn to_hhmm(t: Timestamp) -> String {
  let #(_date, time_of_day) = timestamp.to_calendar(t, calendar.local_offset())
  let hours = int.to_string(time_of_day.hours) |> string.pad_start(2, "0")
  let minutes = int.to_string(time_of_day.minutes) |> string.pad_start(2, "0")
  hours <> ":" <> minutes
}
