--- migration:up
ALTER TABLE users ADD COLUMN email_confirmation_hash TEXT;

UPDATE users
	SET email_confirmation_hash = gen_random_uuid()::text
	WHERE email_verified = FALSE;

ALTER TABLE users
	ALTER COLUMN email_confirmation_hash SET DEFAULT gen_random_uuid()::text;

ALTER TABLE users
	ADD CONSTRAINT users_email_must_match_email_confirmation_hash
	CHECK (email_verified = (email_confirmation_hash IS NULL));

--- migration:down
ALTER TABLE users DROP CONSTRAINT users_email_must_match_email_confirmation_hash;
ALTER TABLE users DROP COLUMN email_confirmation_hash;

--- migration:end
