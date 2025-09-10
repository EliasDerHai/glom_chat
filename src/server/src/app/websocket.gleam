import app/persist/pool.{type DbPool}
import gleam/option
import mist.{type Next, type WebsocketMessage}

pub fn handle_ws_request(db: pool.DbPool) {
  fn(req) {
    mist.websocket(
      request: req,
      on_init: fn(_conn) { #(Nil, option.None) },
      on_close: fn(_state) { Nil },
      handler: fn(state, msg, conn) { handle_ws_message(state, msg, conn, db) },
    )
  }
}

fn handle_ws_message(
  state: state,
  msg: WebsocketMessage(message),
  conn: mist.WebsocketConnection,
  db: DbPool,
) -> Next(state, conn) {
  case msg {
    mist.Text(text) -> {
      handle_text_messages(text, conn, db)
      mist.continue(state)
    }
    mist.Binary(_) | mist.Custom(_) -> mist.continue(state)
    mist.Closed | mist.Shutdown -> mist.stop()
  }
}

fn handle_text_messages(
  raw: String,
  conn: mist.WebsocketConnection,
  _db: DbPool,
) -> Nil {
  let r = case raw {
    "ping" -> mist.send_text_frame(conn, "pong")
    _ -> mist.send_text_frame(conn, "echo: " <> raw)
  }

  case r {
    Error(error_reason) -> {
      echo error_reason
      Nil
    }
    Ok(Nil) -> Nil
  }
}
