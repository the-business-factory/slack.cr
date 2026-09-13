struct Slack::UI::Checked::BlockElements::Button
  TEXT_MAX_LENGTH                =   75
  ACTION_ID_MAX_LENGTH           =  255
  URL_MAX_LENGTH                 = 3000
  VALUE_MAX_LENGTH               = 2000
  ACCESSIBILITY_LABEL_MAX_LENGTH =   75
  AGENT_PROMPT_MAX_LENGTH        = 4000

  getter text : Slack::UI::Checked::CompositionObjects::PlainText
  getter action_id : String?
  getter url : String?
  getter value : String?
  getter style : ButtonStyle?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter accessibility_label : String?
  getter agent_prompt : String?

  def initialize(
    @text : Slack::UI::Checked::CompositionObjects::PlainText,
    @action_id : String? = nil,
    @url : String? = nil,
    @value : String? = nil,
    @style : ButtonStyle? = nil,
    @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil,
    @accessibility_label : String? = nil,
    @agent_prompt : String? = nil,
  )
    validate!
  end

  def type : String
    "button"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    append_length_issue(issues, @text.text, TEXT_MAX_LENGTH, "button.text.too_long", "text.text")
    append_optional_length_issue(issues, @action_id, ACTION_ID_MAX_LENGTH, "button.action_id.too_long", "action_id")
    append_optional_length_issue(issues, @url, URL_MAX_LENGTH, "button.url.too_long", "url")
    append_optional_length_issue(issues, @value, VALUE_MAX_LENGTH, "button.value.too_long", "value")
    append_optional_length_issue(
      issues,
      @accessibility_label,
      ACCESSIBILITY_LABEL_MAX_LENGTH,
      "button.accessibility_label.too_long",
      "accessibility_label"
    )
    append_optional_length_issue(issues, @agent_prompt, AGENT_PROMPT_MAX_LENGTH, "button.agent_prompt.too_long", "agent_prompt")
    if confirmation = @confirm
      confirmation.validate.each { |issue| issues << issue.at("confirm") }
    end
    if (style = @style) && !ButtonStyle.valid?(style)
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "button.style.invalid",
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
      json.field "type", type
      json.field "text", @text
      json.field "action_id", @action_id if @action_id
      json.field "url", @url if @url
      json.field "value", @value if @value
      json.field "style", @style.try(&.wire_value) if @style
      json.field "confirm", @confirm if @confirm
      json.field "accessibility_label", @accessibility_label if @accessibility_label
      json.field "agent_prompt", @agent_prompt if @agent_prompt
    end
  end

  private def append_optional_length_issue(
    issues : Array(Slack::UI::Checked::ValidationIssue),
    value : String?,
    maximum : Int32,
    code : String,
    path : String,
  ) : Nil
    return unless value

    append_length_issue(issues, value, maximum, code, path)
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
      message: "Value cannot be longer than #{maximum} characters."
    )
  end
end
