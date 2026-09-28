require "uri"

module Slack::Api
  # Reads an app's manifest. Requires an app configuration token.
  # See https://docs.slack.dev/reference/methods/apps.manifest.export.
  struct AppsManifestExport < Request(Models::Apps::ManifestExport)
    include FormBody

    getter app_id : String

    def initialize(@app_id : String)
    end

    def method_path : String
      "apps.manifest.export"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      URI::Params{"app_id" => @app_id}
    end
  end
end
