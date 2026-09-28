require "json"

module Slack::Api
  # Joins a public channel and returns it.
  # See https://docs.slack.dev/reference/methods/conversations.join.
  #
  # Slack warns with `already_in_channel` when the caller is a member.
  struct ConversationsJoin < Request(Models::Conversation)
    include JsonBody
    include JSON::Serializable

    getter channel : String

    def initialize(@channel : String)
    end

    def method_path : String
      "conversations.join"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
