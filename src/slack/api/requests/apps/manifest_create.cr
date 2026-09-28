require "json"
require "uri"
require "./manifest_form"

module Slack::Api
  # Creates an app from a manifest. Requires an app configuration token.
  # See https://docs.slack.dev/reference/methods/apps.manifest.create.
  #
  # The manifest stays raw JSON; see https://docs.slack.dev/reference/app-manifest.
  # When Slack rejects the manifest, `Api::Error#details` gives each problem.
  struct AppsManifestCreate < Request(Models::Apps::ManifestCreate)
    include FormBody
    include ManifestForm

    # The workspace that hosts the app, when the token is an organization token.
    getter team_id : String?
    @manifest : JSON::Any

    def initialize(manifest : JSON::Any, *, @team_id : String? = nil)
      @manifest = manifest.clone
    end

    def method_path : String
      "apps.manifest.create"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier1
    end

    def form : URI::Params
      form = manifest_form
      @team_id.try { |team_id| form.add "team_id", team_id }
      form
    end
  end
end
