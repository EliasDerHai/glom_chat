import app_types.{
  type Model, type Msg, GlobalState, LoggedIn, LoginState, Model, Pending,
  RemoveToast,
}
import gleam/list
import gleam/order
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import lustre/effect.{type Effect}
import util/time_util
import util/toast.{type Toast}

pub fn show_toast(
  model: app_types.Model,
  toast_msg: Toast,
) -> #(app_types.Model, Effect(Msg)) {
  let new_toasts = toast.add_toast(model.global_state.toasts, toast_msg)
  let new_global_state = GlobalState(new_toasts)
  let timeout_effect =
    effect.from(fn(dispatch) {
      time_util.set_timeout(
        fn() { dispatch(RemoveToast(toast_msg.id)) },
        toast_msg.duration,
      )
    })
  #(Model(model.app_state, new_global_state), timeout_effect)
}

pub fn remove_toast(model: Model, toast_id: Int) -> #(Model, Effect(Msg)) {
  let new_toasts = toast.remove_toast_by_id(model.global_state.toasts, toast_id)
  let new_global_state = GlobalState(new_toasts)
  #(Model(model.app_state, new_global_state), effect.none())
}

/// deriving socket-conn-lost info directly from model
/// error toast shows after 5 sec without socket conn
pub fn toast_incl_socket_disconnet(model: Model) {
  case model.app_state {
    LoggedIn(LoginState(_, Pending(since), _)) -> {
      case
        timestamp.compare(
          since |> timestamp.add(duration.seconds(5)),
          timestamp.system_time(),
        )
      {
        order.Gt ->
          toast.add_toast(
            model.global_state.toasts,
            toast.create_error_toast("Socket connection lost - reconnecting..."),
          )
        _ -> model.global_state.toasts
      }
    }
    _ ->
      list.filter(model.global_state.toasts, fn(toast_msg) {
        !string.starts_with(toast_msg.content, "Socket connection lost")
      })
  }
}
