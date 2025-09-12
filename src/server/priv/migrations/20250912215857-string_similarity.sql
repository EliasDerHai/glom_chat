--- migration:up
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE INDEX IF NOT EXISTS users_username_trgm_idx
  ON users USING GIN (lower(username) gin_trgm_ops);

--- migration:down
DROP INDEX IF EXISTS users_username_trgm_idx;
DROP EXTENSION IF EXISTS fuzzystrmatch;
DROP EXTENSION IF EXISTS pg_trgm;

--- migration:end
