# One page of `conversations.list`. Each item reads as its conversation type.
struct Slack::Models::ConversationsList < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer channels : Array(Conversation)
end
