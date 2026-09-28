require "uri"

module Slack::Api
  # Adds a file from an external service to Slack.
  # See https://docs.slack.dev/reference/methods/files.remote.add.
  #
  # `indexable_file_contents` and `preview_image` need multipart uploads and are not sent.
  struct FilesRemoteAdd < Request(Models::Files::FileResponse)
    include FormBody

    getter external_id : String
    getter external_url : String
    getter title : String
    getter filetype : String?

    def initialize(*, @external_id : String, @external_url : String, @title : String, @filetype : String? = nil)
    end

    def method_path : String
      "files.remote.add"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier2
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      {"external_id" => @external_id, "external_url" => @external_url, "title" => @title}.each do |field, value|
        next unless value.empty?
        issues << UI::ValidationIssue.new("files_remote_add.#{field}.empty", field, "#{field} must not be empty.")
      end
      issues
    end

    def form : URI::Params
      form = URI::Params{"external_id" => @external_id, "external_url" => @external_url, "title" => @title}
      @filetype.try { |filetype| form.add "filetype", filetype }
      form
    end
  end
end
