struct Slack::UI::Checked::Blocks::Header
  include Slack::UI::Checked::ValueValidation

  getter text : Slack::UI::Checked::CompositionObjects::PlainText
  getter block_id : String?
  getter level : Int32?

  def initialize(@text : Slack::UI::Checked::CompositionObjects::PlainText, @block_id : String? = nil, @level : Int32? = nil)
    validate!
  end

  def type : String
    "header"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    length_issue(issues, @text.text, 150, "header.text.too_long", "text.text")
    length_issue(issues, @block_id, 255, "header.block_id.too_long", "block_id")
    if level = @level
      unless 1 <= level <= 4
        issues << Slack::UI::Checked::ValidationIssue.new("header.level.invalid", "level", "Heading level must be between 1 and 4.")
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "text", @text
      json.field "block_id", @block_id if @block_id
      json.field "level", @level if @level
    end
  end
end
