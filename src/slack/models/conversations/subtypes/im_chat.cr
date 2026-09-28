# A direct message. `conversations.list` items have no `latest` message.
struct Slack::Models::IMChat < Slack::Models::Conversation
  property user : String
  property latest : Slack::Models::DirectMessage?

  property? is_im = true
end
