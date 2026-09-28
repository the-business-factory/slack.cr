require "uri"

module Slack::Api
  # Revokes the calling token. See https://docs.slack.dev/reference/methods/auth.revoke.
  #
  # In test mode (`test: true`), Slack checks the call but keeps the token.
  struct AuthRevoke < Request(Models::Auth::Revoke)
    include FormBody

    getter? test : Bool

    def initialize(*, @test : Bool = false)
    end

    def method_path : String
      "auth.revoke"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      form = URI::Params.new
      form.add "test", "true" if @test
      form
    end
  end
end
