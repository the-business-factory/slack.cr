require "json"

module Slack::Api
  # One uploaded file to complete, with an optional title.
  # See https://docs.slack.dev/reference/methods/files.completeUploadExternal.
  struct FileReference
    getter id : String
    getter title : String?

    def initialize(@id : String, @title : String? = nil)
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @id.empty?
        issues << UI::ValidationIssue.new("file_reference.id.empty", "id", "File ID must not be empty.")
      end
      issues
    end

    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "id", @id
        json.field "title", @title if @title
      end
    end
  end
end
