require "json"

module Slack::Api
  # Deletes a message. See https://docs.slack.dev/reference/methods/chat.delete.
  struct ChatDelete < Request(Models::Chat::Delete)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter ts : String

    def initialize(@channel : String, @ts : String)
    end

    def method_path : String
      "chat.delete"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
