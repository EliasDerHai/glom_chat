DELETE FROM sessions WHERE expires_at <= now();
