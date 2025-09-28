INSERT INTO users (id, username, email, email_verified, password_hash, email_confirmation_hash)
VALUES ($1, $2, $3, $4, crypt($5, gen_salt('bf', 12)), $6);
