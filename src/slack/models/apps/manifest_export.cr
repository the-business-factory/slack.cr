require "json"

module Slack::Models::Apps
  # The `apps.manifest.export` result. The manifest stays raw JSON;
  # see https://docs.slack.dev/reference/app-manifest.
  struct ManifestExport
    include JSON::Serializable

    getter manifest : JSON::Any
  end
end
