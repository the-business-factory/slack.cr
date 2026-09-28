require "json"

module Slack::Api
  # Replaces an app manifest. Requires an app configuration token.
  # See https://docs.slack.dev/reference/methods/apps.manifest.update.
  #
  # The manifest stays raw JSON; see https://docs.slack.dev/reference/app-manifest.
  struct AppsManifestUpdate < Request(Models::Apps::ManifestUpdate)
    include JsonBody
    include JSON::Serializable

    getter app_id : String
    getter manifest : JSON::Any

    def initialize(@app_id : String, @manifest : JSON::Any)
    end

    def method_path : String
      "apps.manifest.update"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier1
    end
  end
end
