require "uri"

module Slack::Api
  # Unpins a message from its channel. See https://docs.slack.dev/reference/methods/pins.remove.
  struct PinsRemove < Request(Models::DefaultResponse)
    include FormBody

    getter channel : String
    getter timestamp : String

    def initialize(@channel : String, @timestamp : String)
    end

    def method_path : String
      "pins.remove"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      URI::Params{"channel" => @channel, "timestamp" => @timestamp}
    end
  end
end
