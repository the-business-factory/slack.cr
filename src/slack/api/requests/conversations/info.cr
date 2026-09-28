require "uri"

module Slack::Api
  # Reads one conversation. See https://docs.slack.dev/reference/methods/conversations.info.
  struct ConversationsInfo < Request(Models::Conversation)
    include FormBody

    getter channel : String

    def initialize(@channel : String)
    end

    def method_path : String
      "conversations.info"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      URI::Params{"channel" => @channel}
    end
  end
end
