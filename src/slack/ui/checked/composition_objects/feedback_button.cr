# One button of a `BlockElements::FeedbackButtons` pair. Slack sends `value`
# in the interaction payload.
struct Slack::UI::Checked::CompositionObjects::FeedbackButton
  include Slack::UI::Checked::ValueValidation

  getter text : PlainText
  getter value : String
  getter accessibility_label : String?

  def initialize(*, @text : PlainText, @value : String, @accessibility_label : String? = nil)
    validate!
  end

  def validate : Array(ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    length_issue(issues, @text.text, 75, "feedback_button.text.too_long", "text.text")
    length_issue(issues, @value, 2000, "feedback_button.value.too_long", "value")
    length_issue(issues, @accessibility_label, 75, "feedback_button.accessibility_label.too_long", "accessibility_label")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "text", @text
      json.field "value", @value
      json.field "accessibility_label", @accessibility_label if @accessibility_label
    end
  end
end
