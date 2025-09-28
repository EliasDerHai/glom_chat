--- migration:up
ALTER TABLE users 
	ADD COLUMN email_confirmation_hash	UUID	UNIQUE	NOT NULL DEFAULT gen_random_uuid(),
	ADD COLUMN created_at			TIMESTAMP	NOT NULL DEFAULT now();

--- migration:down
ALTER TABLE users 
	DROP COLUMN email_confirmation_hash, 
	DROP COLUMN created_at;

--- migration:end
