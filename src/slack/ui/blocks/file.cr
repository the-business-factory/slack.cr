# Displays a remote file that the app added to Slack. Slack lists messages as
# the only surface, so only `MessageSourceBlock` includes it. Slack does not let
# apps add it to messages directly: share remote files with
# `files.remote.share`, or use the block in a `chat.unfurl` request.
struct Slack::UI::Checked::Blocks::File
  include Slack::UI::Checked::ValueValidation

  getter external_id : String
  getter block_id : String?

  def initialize(@external_id : String, @block_id : String? = nil)
    validate!
  end

  def type : String
    "file"
  end

  # Slack currently supports only remote file sources.
  def source : String
    "remote"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @external_id.empty?
      issues << Slack::UI::Checked::ValidationIssue.new("file.external_id.empty", "external_id", "External file ID must not be empty.")
    end
    length_issue(issues, @block_id, 255, "file.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "external_id", @external_id
      json.field "source", source
      json.field "block_id", @block_id if @block_id
    end
  end
end
