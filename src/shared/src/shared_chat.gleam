import gleam/time/timestamp.{type Timestamp}

pub type ChatConversation {
  ChatConversation(
    /// user_id
    participants: List(String),
    messages: List(ChatMessage),
  )
}

pub type ChatMessage {
  ChatMessage(
    /// user_id
    sender: String,
    /// user_ids
    receiver: List(String),
    delivery: ChatMessageDelivery,
    /// utc when server received (sent) message
    sent_time: Timestamp,
    /// `\n` is splitted to allow delimiter agnostic newlines
    content: List(String),
  )
}

pub type ChatMessageDelivery {
  /// user is actively typing msg or switched tabs/conversations but hasn't sent msg yet
  Draft
  /// msg is being sent server hasn't received
  Sending
  /// msg has been sent to server
  Sent
  /// msg has been delivered to receiver
  Delivered
  /// msg has been opened and read by receiver
  Read
}
