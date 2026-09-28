struct Slack::UI::Checked::RichText::Color
  include NodeValidation

  getter value : String
  getter style : Style?

  def initialize(@value : String, @style : Style? = nil)
    validate!
  end

  def type : String
    "color"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @value, "color.value.empty", "value")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "value", @value
      json.field "style", @style if @style
    end
  end
end
