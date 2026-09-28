require "uri"

module Slack::Api
  # Uninstalls the app from the workspace of the calling bot or user token and
  # revokes all tokens of that installation.
  # See https://docs.slack.dev/reference/methods/apps.uninstall.
  #
  # The client secret is kept as an `Auth::Secret`, so `inspect` and `to_s` redact it.
  struct AppsUninstall < Request(Models::DefaultResponse)
    include FormBody

    getter client_id : String
    getter client_secret : Auth::Secret

    def initialize(*, @client_id : String, client_secret : String | Auth::Secret)
      @client_secret = client_secret.is_a?(Auth::Secret) ? client_secret : Auth::Secret.new(client_secret)
    end

    def method_path : String
      "apps.uninstall"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier1
    end

    def form : URI::Params
      URI::Params{"client_id" => @client_id, "client_secret" => @client_secret.value}
    end
  end
end
