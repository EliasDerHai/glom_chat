SELECT id, username FROM users WHERE id = ANY($1);
