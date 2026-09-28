require "json"

module Slack::Api
  # Archives a conversation.
  # See https://docs.slack.dev/reference/methods/conversations.archive.
  #
  # Slack raises `already_archived` for an archived conversation.
  struct ConversationsArchive < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter channel : String

    def initialize(@channel : String)
    end

    def method_path : String
      "conversations.archive"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end
  end
end
