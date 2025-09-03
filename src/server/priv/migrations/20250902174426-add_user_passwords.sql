--- migration:up
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DELETE FROM users;
ALTER TABLE users 
	ADD COLUMN password_hash TEXT		NOT NULL	  , 
	-- timestamptz not supported :/
	ADD COLUMN last_login	 TIMESTAMP			  ,
	ADD COLUMN failed_logins INT		NOT NULL DEFAULT 0;

--- migration:down
ALTER TABLE users 
	DROP COLUMN password_hash,
	DROP COLUMN last_login	 ,
	DROP COLUMN failed_logins;

--- migration:end
