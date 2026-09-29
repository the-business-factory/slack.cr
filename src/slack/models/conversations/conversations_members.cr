# One page of `conversations.members`: user IDs.
struct Slack::Models::ConversationsMembers < Slack::Model
  include Slack::Api::Envelope
  properties_with_initializer members : Array(String)
end
