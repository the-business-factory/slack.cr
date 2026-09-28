# A checkbox choice with plain-text or Markdown label and description.
struct Slack::UI::CompositionObjects::CheckboxOption
  include Slack::UI::ValueValidation

  getter text : PlainText | Mrkdwn
  getter value : String
  getter description : (PlainText | Mrkdwn)?

  def initialize(*, @text : PlainText | Mrkdwn, @value : String, @description : (PlainText | Mrkdwn)? = nil)
    validate!
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    length_issue(issues, @text.text, 75, "checkbox_option.text.too_long", "text.text")
    length_issue(issues, @value, 150, "checkbox_option.value.too_long", "value")
    if description = @description
      description.validate.each { |issue| issues << issue.at("description") }
      length_issue(issues, description.text, 75, "checkbox_option.description.too_long", "description.text")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "text", @text
      json.field "value", @value
      json.field "description", @description if @description
    end
  end
end
