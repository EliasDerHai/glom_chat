SELECT id
FROM users
WHERE username = $1
  AND password_hash = crypt($2, password_hash);
