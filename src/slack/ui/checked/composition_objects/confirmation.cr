struct Slack::UI::Checked::CompositionObjects::Confirmation
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

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    append_child_issues(issues, @title.validate, "title")
    append_child_issues(issues, @text.validate, "text")
    append_child_issues(issues, @confirm.validate, "confirm")
    append_child_issues(issues, @deny.validate, "deny")
    append_length_issue(issues, @title.text, TITLE_MAX_LENGTH, "confirmation.title.too_long", "title.text")
    append_length_issue(issues, @text.text, TEXT_MAX_LENGTH, "confirmation.text.too_long", "text.text")
    append_length_issue(issues, @confirm.text, BUTTON_MAX_LENGTH, "confirmation.confirm.too_long", "confirm.text")
    append_length_issue(issues, @deny.text, BUTTON_MAX_LENGTH, "confirmation.deny.too_long", "deny.text")
    if (style = @style) && !ConfirmationStyle.valid?(style)
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "confirmation.style.invalid",
        path: "style",
        message: "Style must be primary or danger."
      )
    end
    issues
  end

  def validate! : Nil
    issues = validate
    raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?
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
    issues : Array(Slack::UI::Checked::ValidationIssue),
    child_issues : Array(Slack::UI::Checked::ValidationIssue),
    path : String,
  ) : Nil
    child_issues.each { |issue| issues << issue.at(path) }
  end

  private def append_length_issue(
    issues : Array(Slack::UI::Checked::ValidationIssue),
    value : String,
    maximum : Int32,
    code : String,
    path : String,
  ) : Nil
    return unless value.size > maximum

    issues << Slack::UI::Checked::ValidationIssue.new(
      code: code,
      path: path,
      message: "Text cannot be longer than #{maximum} characters."
    )
  end
end
