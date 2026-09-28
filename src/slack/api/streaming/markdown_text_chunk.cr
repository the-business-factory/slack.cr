# Streamed text with markdown formatting.
struct Slack::Api::Streaming::MarkdownTextChunk
  include Slack::UI::ValueValidation

  getter text : String

  def initialize(@text : String)
    validate!
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @text.empty?
      issues << Slack::UI::ValidationIssue.new("markdown_text.text.empty", "text", "Text must not be empty.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", "markdown_text"
      json.field "text", @text
    end
  end
end
