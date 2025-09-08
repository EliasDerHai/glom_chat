import gleam/time/duration.{type Duration}

pub type Toast {
  Toast(content: String, toast_style: ToastStyle, duration: Duration)
}

pub type ToastStyle {
  Info
  Warning
  Failure
}
