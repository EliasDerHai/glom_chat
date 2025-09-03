SELECT id
FROM users
WHERE user_name = $1
  AND password_hash = crypt($2, password_hash);
