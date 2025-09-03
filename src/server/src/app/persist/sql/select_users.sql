SELECT id, user_name, email, email_verified, last_login, failed_logins FROM users ORDER BY ID LIMIT $1 OFFSET $2;
