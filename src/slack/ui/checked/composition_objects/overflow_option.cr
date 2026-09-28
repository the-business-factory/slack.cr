# Plain-text overflow option, optionally opening a URL in the browser.
struct Slack::UI::Checked::CompositionObjects::OverflowOption
  include Slack::UI::Checked::ValueValidation

  getter text : PlainText
  getter value : String
  getter description : PlainText?
  getter url : String?

  def initialize(*, @text : PlainText, @value : String, @description : PlainText? = nil, @url : String? = nil)
    validate!
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    length_issue(issues, @text.text, 75, "overflow_option.text.too_long", "text.text")
    length_issue(issues, @value, 150, "overflow_option.value.too_long", "value")
    if description = @description
      description.validate.each { |issue| issues << issue.at("description") }
      length_issue(issues, description.text, 75, "overflow_option.description.too_long", "description.text")
    end
    length_issue(issues, @url, 3000, "overflow_option.url.too_long", "url")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "text", @text
      json.field "value", @value
      json.field "description", @description if @description
      json.field "url", @url if @url
    end
  end
end
