import dot_env
import dot_env/env
import gleam/io
import wisp

/// Only loads .env file if DATABASE_URL is not already set
/// This allows using env vars set by docker-compose
pub fn load_dot_env() -> Nil {
  case env.get_string("DATABASE_URL") {
    Ok(_) -> {
      io.println("Environment variables already set - skipping .env file")
    }
    Error(_) -> {
      io.println("Loading .env file for local development")
      dot_env.new()
      |> dot_env.set_path(".env")
      |> dot_env.set_debug(False)
      |> dot_env.load
    }
  }
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
