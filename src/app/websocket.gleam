import mist

/// echo/ping example
pub fn handle_ws_message(
  state: a,
  msg: mist.WebsocketMessage(b),
  conn: mist.WebsocketConnection,
) -> mist.Next(a, c) {
  case msg {
    mist.Text("ping") -> {
      let _ = mist.send_text_frame(conn, "pong")
      mist.continue(state)
    }
    mist.Text(text) -> {
      let _ = mist.send_text_frame(conn, "echo: " <> text)
      mist.continue(state)
    }
    mist.Binary(_) | mist.Custom(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}
