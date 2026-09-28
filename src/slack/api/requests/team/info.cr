require "uri"

module Slack::Api
  # Reads the current workspace. See https://docs.slack.dev/reference/methods/team.info.
  struct TeamInfo < Request(Models::Team)
    include FormBody

    def method_path : String
      "team.info"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      URI::Params.new
    end
  end
end
