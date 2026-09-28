# A private channel or a group direct message (`is_mpim?`).
struct Slack::Models::PrivateChannel < Slack::Models::Conversation
  property name : String
  property creator : String?
  property purpose : JSON::Any?
  property topic : JSON::Any?

  property? is_archived = false,
    is_member = false,
    is_mpim = false,
    is_shared = false
end
