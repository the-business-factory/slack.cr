require "uri"

module Slack::Api
  # Checks that the Web API is reachable. Needs no token or scope.
  # See https://docs.slack.dev/reference/methods/api.test.
  #
  # With `error`, Slack fails the call with that error code, so `Client#call`
  # raises `Api::Error` with it. Use this to test error handling.
  struct ApiTest < Request(Models::ApiTest)
    include FormBody

    getter error : String?

    def initialize(*, @error : String? = nil)
    end

    def method_path : String
      "api.test"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def form : URI::Params
      form = URI::Params.new
      @error.try { |error| form.add "error", error }
      form
    end
  end
end
