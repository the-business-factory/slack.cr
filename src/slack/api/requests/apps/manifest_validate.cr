require "json"
require "uri"
require "./manifest_form"

module Slack::Api
  # Checks a manifest against the app manifest schema. Requires an app configuration token.
  # See https://docs.slack.dev/reference/methods/apps.manifest.validate.
  #
  # A valid manifest returns normally. For an invalid manifest, Slack returns
  # `invalid_manifest` and `Api::Error#details` gives each problem and its pointer.
  struct AppsManifestValidate < Request(Models::DefaultResponse)
    include FormBody
    include ManifestForm

    # The app whose configuration Slack checks the manifest against.
    getter app_id : String?
    @manifest : JSON::Any

    def initialize(manifest : JSON::Any, *, @app_id : String? = nil)
      @manifest = manifest.clone
    end

    def method_path : String
      "apps.manifest.validate"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def form : URI::Params
      form = manifest_form
      @app_id.try { |app_id| form.add "app_id", app_id }
      form
    end
  end
end
