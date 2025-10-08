UPDATE chat_messages
SET delivery = $1 
WHERE id = ANY($2) 
	AND delivery != $1
	AND receiver_id = $3
RETURNING id, sender_id;
