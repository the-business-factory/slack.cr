require "uri"

module Slack::Api
  # Reads one file. See https://docs.slack.dev/reference/methods/files.info.
  # File comments and their pagination are not read.
  struct FilesInfo < Request(Models::Files::FileResponse)
    include FormBody

    getter file : String

    def initialize(@file : String)
    end

    def method_path : String
      "files.info"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @file.empty?
        issues << UI::ValidationIssue.new("files_info.file.empty", "file", "File ID must not be empty.")
      end
      issues
    end

    def form : URI::Params
      URI::Params{"file" => @file}
    end
  end
end
