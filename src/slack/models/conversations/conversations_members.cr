# One page of `conversations.members`: user IDs.
struct Slack::Models::ConversationsMembers < Slack::Model
  properties_with_initializer members : Array(String)
end
