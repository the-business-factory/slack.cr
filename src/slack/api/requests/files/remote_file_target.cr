require "uri"

module Slack::Api
  # Selects a remote file by its Slack file ID or by the app's external ID.
  # `files.remote.*` methods accept either one, not both.
  struct RemoteFileTarget
    getter field : String
    getter id : String

    private def initialize(@field : String, @id : String)
    end

    # Selects the remote file with Slack file ID *id*, such as `F08EAQ813FW`.
    def self.file(id : String) : self
      new("file", id)
    end

    # Selects the remote file that the app added with *external_id*.
    def self.external_id(external_id : String) : self
      new("external_id", external_id)
    end

    def validate : Array(UI::ValidationIssue)
      issues = [] of UI::ValidationIssue
      if @id.empty?
        issues << UI::ValidationIssue.new("remote_file_target.id.empty", @field, "Remote file ID must not be empty.")
      end
      issues
    end

    def add_to(form : URI::Params) : Nil
      form.add @field, @id
    end
  end
end
