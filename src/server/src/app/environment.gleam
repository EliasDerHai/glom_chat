import dot_env
import dot_env/env
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
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

pub fn is_prod() {
  ["localhost", "127.0.0.1"]
  |> list.contains(get_server_host())
  |> bool.negate
}

pub fn get_public_url() -> String {
  get_string_or("PUBLIC_URL", "http://localhost:8000")
}

pub type SenderEmailInfos {
  SenderEmailInfos(email_address: String, name: String, app_key: String)
}

pub fn get_sender_email_infos() -> SenderEmailInfos {
  SenderEmailInfos(
    get_string_or("EMAIL", ""),
    get_string_or("EMAIL_NAME", ""),
    get_string_or("EMAIL_APP_KEY", ""),
  )
}

// utils --------------------------------------------------

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
