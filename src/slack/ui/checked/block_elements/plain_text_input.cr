struct Slack::UI::Checked::BlockElements::PlainTextInput
  include Slack::UI::Checked::ValueValidation

  getter action_id : String?
  getter initial_value : String?
  getter multiline : Bool?
  getter min_length : Int32?
  getter max_length : Int32?
  getter dispatch_action_config : Slack::UI::Checked::CompositionObjects::DispatchActionConfig?
  getter focus_on_load : Bool?
  getter placeholder : Slack::UI::Checked::CompositionObjects::PlainText?

  def initialize(
    @action_id : String? = nil,
    @initial_value : String? = nil,
    @multiline : Bool? = nil,
    @min_length : Int32? = nil,
    @max_length : Int32? = nil,
    @dispatch_action_config : Slack::UI::Checked::CompositionObjects::DispatchActionConfig? = nil,
    @focus_on_load : Bool? = nil,
    @placeholder : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
  )
    validate!
  end

  def type : String
    "plain_text_input"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    length_issue(issues, @action_id, 255, "plain_text_input.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "plain_text_input.placeholder.too_long", "placeholder.text")
    end
    if config = @dispatch_action_config
      config.validate.each { |issue| issues << issue.at("dispatch_action_config") }
    end
    if (minimum = @min_length) && !minimum.in?(0..3000)
      issues << Slack::UI::Checked::ValidationIssue.new("plain_text_input.min_length.out_of_range", "min_length", "Minimum length must be between 0 and 3000.")
    end
    if (maximum = @max_length) && !maximum.in?(1..3000)
      issues << Slack::UI::Checked::ValidationIssue.new("plain_text_input.max_length.out_of_range", "max_length", "Maximum length must be between 1 and 3000.")
    end
    if (minimum = @min_length) && (maximum = @max_length) && minimum > maximum
      issues << Slack::UI::Checked::ValidationIssue.new("plain_text_input.length.inverted", "min_length", "Minimum length cannot exceed maximum length.")
    end
    # Slack documents no initial_value limit or relationship with min/max_length.
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "initial_value", @initial_value if @initial_value
      json.field "multiline", @multiline unless @multiline.nil?
      json.field "min_length", @min_length unless @min_length.nil?
      json.field "max_length", @max_length unless @max_length.nil?
      json.field "dispatch_action_config", @dispatch_action_config if @dispatch_action_config
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
      json.field "placeholder", @placeholder if @placeholder
    end
  end
end
