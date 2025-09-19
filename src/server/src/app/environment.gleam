import dot_env
import dot_env/env
import gleam/int
import gleam/io
import gleam/string
import wisp

/// Only loads .env file if DATABASE_URL is not already set
/// This allows using env vars set by docker-compose
pub fn load_dot_env() -> Nil {
  case env.get_string("SERVER_SECRET") {
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
        "SERVER_SECRET not found - fallback to random secret (active sessions can't be used after server restart)",
      )
      wisp.random_string(64)
    }
  }
}

pub fn get_server_host() -> String {
  get_string_or("SERVER_HOST", "127.0.0.1")
}

pub fn get_server_port() -> Int {
  get_int_or("SERVER_PORT", 8000)
}

fn get_string_or(key: String, fallback: String) -> String {
  let key = key |> string.uppercase
  case env.get_string(key) {
    Ok(v) -> v
    Error(_) -> {
      io.println(key <> " not found - fallback to " <> fallback)
      fallback
    }
  }
}

fn get_int_or(key: String, fallback: Int) -> Int {
  let key = key |> string.uppercase
  case env.get_int(key) {
    Ok(v) -> v
    Error(e) -> {
      io.println(
        key <> ":" <> e <> " - fallback to " <> fallback |> int.to_string,
      )
      fallback
    }
  }
}
