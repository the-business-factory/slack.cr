require "json"
require "uri"

module Slack::Api
  # :nodoc:
  # Form encoding for the `apps.manifest.*` requests that send a manifest.
  #
  # Slack documents `manifest` as a string, so the form carries the manifest as
  # JSON text. The request keeps its own copy of the manifest and returns copies.
  module ManifestForm
    def manifest : JSON::Any
      @manifest.clone
    end

    private def manifest_form : URI::Params
      URI::Params{"manifest" => @manifest.to_json}
    end
  end
end
