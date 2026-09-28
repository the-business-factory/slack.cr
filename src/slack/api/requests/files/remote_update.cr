require "uri"

module Slack::Api
  # Updates a remote file's title, URL, or type.
  # See https://docs.slack.dev/reference/methods/files.remote.update.
  #
  # `indexable_file_contents` and `preview_image` need multipart uploads and are not sent.
  struct FilesRemoteUpdate < Request(Models::Files::FileResponse)
    include FormBody

    getter target : RemoteFileTarget
    getter title : String?
    getter external_url : String?
    getter filetype : String?

    def initialize(@target : RemoteFileTarget, *, @title : String? = nil, @external_url : String? = nil,
                   @filetype : String? = nil)
    end

    def method_path : String
      "files.remote.update"
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
      @title.try { |title| form.add "title", title }
      @external_url.try { |external_url| form.add "external_url", external_url }
      @filetype.try { |filetype| form.add "filetype", filetype }
      form
    end
  end
end
