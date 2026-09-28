require "uri"

module Slack::Api
  # Deletes one file. See https://docs.slack.dev/reference/methods/files.delete.
  struct FilesDelete < Request(Models::DefaultResponse)
    include FormBody

    getter file : String

    def initialize(@file : String)
    end

    def method_path : String
      "files.delete"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier3
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @file.empty?
        issues << UI::ValidationIssue.new("files_delete.file.empty", "file", "File ID must not be empty.")
      end
      issues
    end

    def form : URI::Params
      URI::Params{"file" => @file}
    end
  end
end
