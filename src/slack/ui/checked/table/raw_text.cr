# A plain text table cell. Nonempty text is library policy.
struct Slack::UI::Checked::Table::RawText
  include Slack::UI::Checked::ValueValidation

  getter text : String

  def initialize(@text : String)
    validate!
  end

  def type : String
    "raw_text"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    issues << ValidationIssue.new("raw_text.text.empty", "text", "Text must not be empty.") if @text.empty?
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
