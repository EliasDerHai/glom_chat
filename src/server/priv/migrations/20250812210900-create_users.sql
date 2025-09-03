--- migration:up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
	id 		UUID		PRIMARY KEY,
	username 	TEXT		NOT NULL UNIQUE,
	email 		TEXT		NOT NULL UNIQUE,
	email_verified 	BOOLEAN		NOT NULL DEFAULT FALSE,
	password_hash	TEXT		NOT NULL, 
	-- timestamptz not supported :/
	last_login	TIMESTAMP,
	failed_logins	INT		NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS sessions (
	id 		UUID		PRIMARY KEY,
	user_id		UUID		NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, 
	created_at	TIMESTAMP	NOT NULL DEFAULT now(),
	expires_at	TIMESTAMP	NOT NULL,
	csrf_secret	TEXT		NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id     ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at  ON sessions(expires_at);

--- migration:down
DROP TABLE sessions;
DROP TABLE users;

--- migration:end
