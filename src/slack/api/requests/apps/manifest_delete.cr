require "uri"

module Slack::Api
  # Permanently deletes an app that was created from a manifest. Requires an app
  # configuration token. See https://docs.slack.dev/reference/methods/apps.manifest.delete.
  struct AppsManifestDelete < Request(Models::DefaultResponse)
    include FormBody

    getter app_id : String

    def initialize(@app_id : String)
    end

    def method_path : String
      "apps.manifest.delete"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier1
    end

    def form : URI::Params
      URI::Params{"app_id" => @app_id}
    end
  end
end
