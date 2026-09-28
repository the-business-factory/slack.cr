# A formatted text composer. Its initial value is a validated rich text block.
struct Slack::UI::BlockElements::RichTextInput
  include Slack::UI::ValueValidation

  getter action_id : String
  getter initial_value : Slack::UI::Blocks::RichText?
  getter dispatch_action_config : Slack::UI::CompositionObjects::DispatchActionConfig?
  getter focus_on_load : Bool?
  getter placeholder : Slack::UI::CompositionObjects::PlainText?
  getter min_lines : Int32?
  getter max_lines : Int32?

  def initialize(
    *,
    @action_id : String,
    @initial_value : Slack::UI::Blocks::RichText? = nil,
    @dispatch_action_config : Slack::UI::CompositionObjects::DispatchActionConfig? = nil,
    @focus_on_load : Bool? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @min_lines : Int32? = nil,
    @max_lines : Int32? = nil,
  )
    validate!
  end

  def type : String
    "rich_text_input"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    # Slack requires action_id for this element; an empty ID is library policy.
    if @action_id.empty?
      issues << Slack::UI::ValidationIssue.new("rich_text_input.action_id.empty", "action_id", "Action ID cannot be empty.")
    end
    length_issue(issues, @action_id, 255, "rich_text_input.action_id.too_long", "action_id")
    if initial_value = @initial_value
      initial_value.validate.each { |issue| issues << issue.at("initial_value") }
    end
    if config = @dispatch_action_config
      config.validate.each { |issue| issues << issue.at("dispatch_action_config") }
    end
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "rich_text_input.placeholder.too_long", "placeholder.text")
    end
    lines_issue(issues, @min_lines, "min_lines")
    lines_issue(issues, @max_lines, "max_lines")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id
      json.field "initial_value", @initial_value if @initial_value
      json.field "dispatch_action_config", @dispatch_action_config if @dispatch_action_config
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
      json.field "placeholder", @placeholder if @placeholder
      json.field "min_lines", @min_lines unless @min_lines.nil?
      json.field "max_lines", @max_lines unless @max_lines.nil?
    end
  end

  # Slack documents 1 to 100 for each field and no rule between them.
  private def lines_issue(issues : Array(Slack::UI::ValidationIssue), lines : Int32?, field : String) : Nil
    if lines && !lines.in?(1..100)
      issues << Slack::UI::ValidationIssue.new("rich_text_input.#{field}.out_of_range", field, "Visible lines must be between 1 and 100.")
    end
  end
end
