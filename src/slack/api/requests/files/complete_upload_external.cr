require "json"
require "uri"

module Slack::Api
  # Completes uploaded files and optionally shares them.
  # See https://docs.slack.dev/reference/methods/files.completeUploadExternal.
  #
  # `files` is sent as JSON text in a form field, like the official SDKs do.
  struct FilesCompleteUploadExternal < Request(Models::Files::CompletedUpload)
    include FormBody

    getter share : FileShare?
    @files : Array(FileReference)

    def initialize(files : Enumerable(FileReference), @share : FileShare? = nil)
      # `Array#to_a` returns self; `map` always makes an owned copy.
      @files = files.map(&.itself)
    end

    def files : Array(FileReference)
      @files.dup
    end

    def method_path : String
      "files.completeUploadExternal"
    end

    def tier : RateLimitTier
      RateLimitTier::Tier4
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @files.empty?
        issues << UI::ValidationIssue.new("files_complete_upload_external.files.empty", "files",
          "Files must contain at least one file.")
      end
      @files.each_with_index do |file, index|
        issues.concat(file.validate.map(&.at("files[#{index}]")))
      end
      @share.try { |share| issues.concat(share.validate) }
      issues
    end

    def form : URI::Params
      form = URI::Params{"files" => @files.to_json}
      @share.try(&.add_to(form))
      form
    end
  end
end
