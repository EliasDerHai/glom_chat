INSERT INTO sessions (id, user_id, expires_at, csrf_secret)
VALUES ($1, $2, $3, $4);