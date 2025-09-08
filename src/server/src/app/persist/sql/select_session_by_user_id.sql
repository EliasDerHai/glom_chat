SELECT id, user_id, created_at, expires_at, csrf_secret
FROM sessions 
WHERE user_id = $1;
