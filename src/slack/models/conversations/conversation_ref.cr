require "json"

module Slack::Models::Conversations
  # A conversation that Slack identifies only by its ID, such as the `channel`
  # of a `conversations.open` response without `return_im`.
  struct ConversationRef
    include JSON::Serializable

    getter id : String
  end
end
