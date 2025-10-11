import gleam/dynamic/decode.{type Dynamic}
import lustre/effect.{type Effect}

pub fn scroll_chat_to_bottom() -> Effect(msg) {
  use _, root_element <- effect.after_paint
  do_scroll_to_bottom(root_element)
}

@external(javascript, "./dom_util.ffi.mjs", "scrollToBottom")
fn do_scroll_to_bottom(in root: Dynamic) -> Nil
