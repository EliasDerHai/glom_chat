import dot_env
import dot_env/env
import gleam/io
import wisp

pub fn load_dot_env() -> Nil {
  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load
}

pub fn get_secret() -> String {
  case env.get_string("SERVER_SECRET") {
    Ok(secret) -> secret
    Error(_) -> {
      io.println(
        "SERVER_SECRET not found in .env - fallback to random secret (active sessions can't be used after server restart)",
      )
      wisp.random_string(64)
    }
  }
}
