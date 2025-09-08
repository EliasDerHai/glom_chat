import gleam/list
import gleam/time/duration.{type Duration}
import gleam/time/timestamp
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

pub fn add_toast(toasts: List(Toast), toast: Toast) -> List(Toast) {
  [toast, ..toasts]
}

pub fn remove_toast_by_id(toasts: List(Toast), toast_id: Int) -> List(Toast) {
  list.filter(toasts, fn(toast) { toast.id != toast_id })
}
