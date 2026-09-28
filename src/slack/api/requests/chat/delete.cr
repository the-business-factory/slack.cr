require "json"

module Slack::Api
  # Deletes a message. See https://docs.slack.dev/reference/methods/chat.delete.
  #
  # `as_user` is a legacy argument: true deletes the message as the authed user.
  struct ChatDelete < Request(Models::Chat::Delete)
    include JsonBody
    include JSON::Serializable

    getter channel : String
    getter ts : String
    getter as_user : Bool?

    def initialize(@channel : String, @ts : String, @as_user : Bool? = nil)
    end

    def method_path : String
      "chat.delete"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end
  end
end
