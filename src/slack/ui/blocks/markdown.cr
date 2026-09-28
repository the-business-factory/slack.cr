# Displays standard markdown, such as a reply from an LLM. Slack translates the
# text into one or more blocks. Slack lists messages as the only surface, so
# only `MessageSourceBlock` includes it.
#
# Slack ignores a markdown block's `block_id` and does not keep it, so this
# block does not accept one.
struct Slack::UI::Blocks::Markdown
  include Slack::UI::ValueValidation

  # Slack's limit for all markdown blocks in one payload. `Message` checks the
  # total.
  TEXT_MAX_SIZE = 12_000

  getter text : String

  def initialize(@text : String)
    validate!
  end

  def type : String
    "markdown"
  end

  # Always `nil`: Slack does not keep a markdown block's `block_id`.
  def block_id : Nil
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @text.empty?
      issues << Slack::UI::ValidationIssue.new("markdown.text.empty", "text", "Markdown text must not be empty.")
    end
    length_issue(issues, @text, TEXT_MAX_SIZE, "markdown.text.too_long", "text")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "text", @text
    end
  end
end
