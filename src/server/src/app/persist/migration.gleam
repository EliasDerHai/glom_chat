import cigogne
import cigogne/types
import gleam/io
import gleam/result

pub fn migrate_db() -> Nil {
  let config = cigogne.default_config

  case
    {
      use engine <- result.try(cigogne.create_engine(config))
      cigogne.apply_to_last(engine)
    }
  {
    // migrations are already logged by cigogne
    Ok(_) -> Nil
    Error(types.NoMigrationToApplyError) -> io.println("nothing to migrate")
    Error(other) -> {
      echo other
      panic as "failed to migrate"
    }
  }
}
