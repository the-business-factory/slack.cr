require "uri"

module Slack::Api
  # Sets the presence of the token's user.
  # See https://docs.slack.dev/reference/methods/users.setPresence.
  struct UsersSetPresence < Request(Models::DefaultResponse)
    include FormBody

    getter presence : PresenceSetting

    def initialize(@presence : PresenceSetting)
    end

    def method_path : String
      "users.setPresence"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def form : URI::Params
      URI::Params{"presence" => @presence.wire_name}
    end
  end
end
