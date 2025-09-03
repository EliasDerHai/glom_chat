SELECT id, username, email, email_verified, last_login, failed_logins FROM users WHERE id = $1;
