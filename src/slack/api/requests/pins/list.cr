require "uri"

module Slack::Api
  # Reads the pinned items of a channel. See https://docs.slack.dev/reference/methods/pins.list.
  struct PinsList < Request(Models::Pins::PinList)
    include FormBody

    getter channel : String

    def initialize(@channel : String)
    end

    def method_path : String
      "pins.list"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      URI::Params{"channel" => @channel}
    end
  end
end
