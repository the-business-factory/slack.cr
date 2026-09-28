struct Slack::UI::RichText::Text
  include NodeValidation

  getter text : String
  getter style : TextStyle?

  def initialize(@text : String, @style : TextStyle? = nil)
    validate!
  end

  def type : String
    "text"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @text, "text.text.empty", "text")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "text", @text
      json.field "style", @style if @style
    end
  end
end
