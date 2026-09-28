require "json"

module Slack::Api
  # Adds an emoji reaction to a message. See https://docs.slack.dev/reference/methods/reactions.add.
  struct ReactionsAdd < Request(Models::DefaultResponse)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter name : String
    getter timestamp : String

    def initialize(@channel : String, @name : String, @timestamp : String)
    end

    def method_path : String
      "reactions.add"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
