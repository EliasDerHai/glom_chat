--- migration:up
CREATE TABLE IF NOT EXISTS users (
	id 		UUID 	PRIMARY KEY,
	user_name 	TEXT 	NOT NULL,
	email 		TEXT 	NOT NULL,
	email_verified 	BOOLEAN NOT NULL DEFAULT FALSE
);

--- migration:down
DROP TABLE users;

--- migration:end
