require "uri"

module Slack::Api
  # Checks the calling token and returns its identity.
  # See https://docs.slack.dev/reference/methods/auth.test.
  struct AuthTest < Request(Models::Auth::Test)
    include FormBody

    def method_path : String
      "auth.test"
    end

    def tier : RateLimitTier
      RateLimitTier::Special
    end

    def form : URI::Params
      URI::Params.new
    end
  end
end
