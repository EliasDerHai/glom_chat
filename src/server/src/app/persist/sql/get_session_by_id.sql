SELECT id, user_id, created_at, expires_at, csrf_secret
FROM sessions 
WHERE id = $1 AND expires_at > now();