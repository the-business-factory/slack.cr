require "json"

module Slack::Api
  # Restores an archived conversation.
  # See https://docs.slack.dev/reference/methods/conversations.unarchive.
  #
  # Slack raises `not_archived` otherwise.
  struct ConversationsUnarchive < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter channel : String

    def initialize(@channel : String)
    end

    def method_path : String
      "conversations.unarchive"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end
  end
end
