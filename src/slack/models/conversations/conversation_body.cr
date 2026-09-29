# :nodoc:
# A Web API response that holds one conversation in `channel`, such as
# `conversations.info` or `conversations.create`.
struct Slack::Models::ConversationBody
  include JSON::Serializable
  include Slack::Api::Envelope

  getter channel : Conversation
end
