require "uri"

module Slack::Api
  # Shares a remote file into channels. This is how an app shows a remote file
  # in a message. See https://docs.slack.dev/reference/methods/files.remote.share.
  struct FilesRemoteShare < Request(Models::Files::FileResponse)
    include FormBody

    getter target : RemoteFileTarget
    @channels : Array(String)

    def initialize(@target : RemoteFileTarget, *, channels : Enumerable(String))
      # `Array#to_a` returns self; `map` always makes an owned copy.
      @channels = channels.map(&.itself)
    end

    def channels : Array(String)
      @channels.dup
    end

    def method_path : String
      "files.remote.share"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = @target.validate
      if @channels.empty?
        issues << UI::ValidationIssue.new("files_remote_share.channels.empty", "channels",
          "Channels must contain at least one ID.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params.new
      @target.add_to(form)
      form.add "channels", @channels.join(',')
      form
    end
  end
end
