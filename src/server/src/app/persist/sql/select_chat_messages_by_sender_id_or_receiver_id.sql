SELECT * FROM chat_messages WHERE sender_id = $1 or receiver_id = $1 ORDER BY created_at;
