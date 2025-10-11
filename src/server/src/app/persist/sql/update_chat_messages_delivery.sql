UPDATE chat_messages
SET delivery = $1 
WHERE id = ANY($2) 
	AND delivery != $1
	AND receiver_id = $3
	AND (
		CASE delivery
			WHEN 'sent' THEN 1
			WHEN 'delivered' THEN 2
			WHEN 'read' THEN 3
		END
	) < (
		CASE $1
			WHEN 'sent' THEN 1
			WHEN 'delivered' THEN 2
			WHEN 'read' THEN 3
		END
	)
RETURNING id, sender_id;
