import gleam/http/request
import mist.{type Connection}

// alias for mist.Request(internal.Connection)
// helpful to discern wisp & mist 
// wisp.Request <-> mist.Request(internal.Connection)
pub type MistRequest =
  request.Request(Connection)
