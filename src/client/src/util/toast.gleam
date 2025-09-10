import gleam/list
import gleam/time/duration.{type Duration}
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import util/time_util

pub type Toast {
  Toast(id: Int, content: String, toast_style: ToastStyle, duration: Duration)
}

pub type ToastStyle {
  Info
  Warning
  Failure
}

pub fn create_info_toast(content: String) -> Toast {
  timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
  Toast(
    time_util.millis_now(),
    content: content,
    toast_style: Info,
    duration: duration.seconds(5),
  )
}

pub fn create_error_toast(content: String) -> Toast {
  timestamp.to_unix_seconds_and_nanoseconds(timestamp.system_time())
  Toast(
    time_util.millis_now(),
    content: content,
    toast_style: Failure,
    duration: duration.seconds(7),
  )
}

pub fn add_toast(toasts: List(Toast), toast: Toast) -> List(Toast) {
  [toast, ..toasts]
}

pub fn remove_toast_by_id(toasts: List(Toast), toast_id: Int) -> List(Toast) {
  list.filter(toasts, fn(toast) { toast.id != toast_id })
}

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
