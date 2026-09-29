struct Slack::UI::CompositionObjects::Confirmation
  include Slack::UI::ValueValidation

  TITLE_MAX_LENGTH  = 100
  TEXT_MAX_LENGTH   = 300
  BUTTON_MAX_LENGTH =  30

  getter title : PlainText
  getter text : Text
  getter confirm : PlainText
  getter deny : PlainText
  getter style : ConfirmationStyle?

  def initialize(
    @title : PlainText,
    @text : Text,
    @confirm : PlainText,
    @deny : PlainText,
    @style : ConfirmationStyle? = nil,
  )
    validate!
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    append_child_issues(issues, @title.validate, "title")
    append_child_issues(issues, @text.validate, "text")
    append_child_issues(issues, @confirm.validate, "confirm")
    append_child_issues(issues, @deny.validate, "deny")
    length_issue(issues, @title.text, TITLE_MAX_LENGTH, "confirmation.title.too_long", "title.text", "Text")
    length_issue(issues, @text.text, TEXT_MAX_LENGTH, "confirmation.text.too_long", "text.text", "Text")
    length_issue(issues, @confirm.text, BUTTON_MAX_LENGTH, "confirmation.confirm.too_long", "confirm.text", "Text")
    length_issue(issues, @deny.text, BUTTON_MAX_LENGTH, "confirmation.deny.too_long", "deny.text", "Text")
    if (style = @style) && !ConfirmationStyle.valid?(style)
      issues << Slack::UI::ValidationIssue.new(
        code: "confirmation.style.invalid",
        path: "style",
        message: "Style must be primary or danger."
      )
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "title", @title
      json.field "text", @text
      json.field "confirm", @confirm
      json.field "deny", @deny
      json.field "style", @style.try(&.wire_value) if @style
    end
  end

  private def append_child_issues(
    issues : Array(Slack::UI::ValidationIssue),
    child_issues : Array(Slack::UI::ValidationIssue),
    path : String,
  ) : Nil
    child_issues.each { |issue| issues << issue.at(path) }
  end
end
