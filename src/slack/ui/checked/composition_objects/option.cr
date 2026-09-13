# Plain-text menu option. URL and markdown variants belong to later slices.
struct Slack::UI::Checked::CompositionObjects::Option
  include Slack::UI::Checked::ValueValidation

  getter text : PlainText
  getter value : String
  getter description : PlainText?

  def initialize(*, @text : PlainText, @value : String, @description : PlainText? = nil)
    validate!
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    length_issue(issues, @text.text, 75, "option.text.too_long", "text.text")
    length_issue(issues, @value, 150, "option.value.too_long", "value")
    if description = @description
      description.validate.each { |issue| issues << issue.at("description") }
      length_issue(issues, description.text, 75, "option.description.too_long", "description.text")
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
