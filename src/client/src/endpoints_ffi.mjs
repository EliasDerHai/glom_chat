export function getApiUrl() {
  if (window.location.hostname.includes("github.io")) {
    return "https://glom-chat.fly.dev/";
  }

  // local development
  return "http://localhost:1234/api/";
}

export function getSocketUrl() {
  if (window.location.hostname.includes("github.io")) {
    return "wss://glom-chat.fly.dev/ws";
  }

  // local development
  return "ws://localhost:8000/ws";
}
