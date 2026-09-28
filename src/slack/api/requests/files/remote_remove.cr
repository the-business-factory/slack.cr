require "uri"

module Slack::Api
  # Removes a remote file from Slack. The file at its source is unchanged.
  # See https://docs.slack.dev/reference/methods/files.remote.remove.
  struct FilesRemoteRemove < Request(Models::DefaultResponse)
    include FormBody

    getter target : RemoteFileTarget

    def initialize(@target : RemoteFileTarget)
    end

    def method_path : String
      "files.remote.remove"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      @target.validate
    end

    def form : URI::Params
      form = URI::Params.new
      @target.add_to(form)
      form
    end
  end
end
