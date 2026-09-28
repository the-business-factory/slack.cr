require "uri"

module Slack::Api
  # Pins a message to its channel. See https://docs.slack.dev/reference/methods/pins.add.
  #
  # Slack answers `already_pinned` when the message is already pinned.
  struct PinsAdd < Request(Models::DefaultResponse)
    include FormBody

    getter channel : String
    getter timestamp : String

    def initialize(@channel : String, @timestamp : String)
    end

    def method_path : String
      "pins.add"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      URI::Params{"channel" => @channel, "timestamp" => @timestamp}
    end
  end
end
