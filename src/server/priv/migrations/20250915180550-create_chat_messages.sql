--- migration:up
-- matches ChatMessageDelivery (no 'draft' and 'sending' state since these are client-only)
CREATE TYPE chat_message_delivery AS ENUM (
	'sent',
	'delivered',
	'read'
);

CREATE TABLE IF NOT EXISTS chat_messages (
	id 		UUID			PRIMARY KEY,
	sender_id	UUID			NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	receiver_id	UUID			NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	delivery	chat_message_delivery	NOT NULL DEFAULT 'sent',
	text_content	TEXT[]			NOT NULL,
	created_at	TIMESTAMP		NOT NULL DEFAULT now(),
	updated_at	TIMESTAMP		NOT NULL DEFAULT now()
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_receiver_id ON chat_messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON chat_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_delivery ON chat_messages(delivery);

--- migration:down
DROP TABLE IF EXISTS chat_messages;
DROP TYPE IF EXISTS chat_message_delivery;

--- migration:end
