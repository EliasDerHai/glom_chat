UPDATE users
SET email_verified = TRUE
WHERE id = $1
	AND email_confirmation_hash = $2
	AND email_verified = FALSE
	AND created_at + INTERVAL '1 day' > now();
