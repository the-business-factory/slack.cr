require "json"

module Slack::Api
  # Leaves a conversation.
  # See https://docs.slack.dev/reference/methods/conversations.leave.
  #
  # Slack raises `cant_leave_general` for the general channel.
  struct ConversationsLeave < Request(Models::Conversations::LeaveResponse)
    include JsonBody
    include JSON::Serializable

    getter channel : String

    def initialize(@channel : String)
    end

    def method_path : String
      "conversations.leave"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
