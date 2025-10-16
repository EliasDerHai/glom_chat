import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/time/duration.{type Duration}
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import util/time

// TYPES -----------------------------------------------------------------------

pub type Toast {
  // id == utc.millis of toast creation
  Toast(id: Int, content: String, toast_style: ToastStyle, duration: Duration)
}

pub type ToastStyle {
  Info
  Warning
  Failure
}

// ENCODING/DECODING -----------------------------------------------------------

pub fn encode_toast(toast: Toast) -> json.Json {
  json.object([
    #("id", json.int(toast.id)),
    #("content", json.string(toast.content)),
    #("toast_style", encode_toast_style(toast.toast_style)),
    #("duration", json.int(time.duration_to_millis(toast.duration))),
  ])
}

pub fn decode_toast() -> decode.Decoder(Toast) {
  use id <- decode.field("id", decode.int)
  use content <- decode.field("content", decode.string)
  use toast_style <- decode.field("toast_style", decode_toast_style())
  use duration <- decode.field("duration", decode.int)

  decode.success(Toast(
    id,
    content,
    toast_style,
    duration.milliseconds(duration),
  ))
}

pub fn encode_toast_style(style: ToastStyle) -> json.Json {
  case style {
    Failure -> "failure"
    Info -> "info"
    Warning -> "warning"
  }
  |> json.string
}

pub fn decode_toast_style() -> decode.Decoder(ToastStyle) {
  decode.string
  |> decode.map(fn(style) {
    case style {
      "failure" -> Failure
      "info" -> Info
      "warning" -> Warning
      other -> panic as { "did not expect ToastStyle '" <> other <> "'" }
    }
  })
}

// INIT -----------------------------------------------------------

pub fn create_info_toast(content: String) -> Toast {
  timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
  Toast(
    time.millis_now(),
    content: content,
    toast_style: Info,
    duration: duration.seconds(5),
  )
}

pub fn create_error_toast(content: String) -> Toast {
  timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
  Toast(
    time.millis_now(),
    content: content,
    toast_style: Failure,
    duration: duration.seconds(7),
  )
}

// UPDATE -----------------------------------------------------------

pub fn add_toast(toasts: List(Toast), toast: Toast) -> List(Toast) {
  [toast, ..toasts]
}

pub fn remove_toast_by_id(toasts: List(Toast), toast_id: Int) -> List(Toast) {
  list.filter(toasts, fn(toast) { toast.id != toast_id })
}

// VIEW -----------------------------------------------------------

pub fn view_toasts(toasts: List(Toast)) -> Element(msg) {
  html.div(
    [
      attribute.class(
        "fixed top-4 right-4 z-50 flex flex-col gap-2 pointer-events-none",
      ),
    ],
    list.map(toasts, view_single_toast),
  )
}

fn view_single_toast(toast: Toast) -> Element(msg) {
  let style_classes = case toast.toast_style {
    Info -> "bg-blue-50 border-blue-200 text-blue-500"
    Warning -> "bg-yellow-50 border-yellow-200 text-yellow-500"
    Failure -> "bg-red-50 border-red-200 text-red-500"
  }

  html.div(
    [
      attribute.class(
        "px-4 py-3 rounded-lg border shadow-sm pointer-events-auto min-w-64 max-w-80 whitespace-pre "
        <> style_classes,
      ),
    ],
    [html.text(toast.content)],
  )
}
