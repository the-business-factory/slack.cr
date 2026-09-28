# Slack's `url_text_input` element. Slack checks the entered URL; the library
# does not check the format of `initial_value`.
struct Slack::UI::BlockElements::UrlInput
  include Slack::UI::ValueValidation

  getter action_id : String?
  getter initial_value : String?
  getter dispatch_action_config : Slack::UI::CompositionObjects::DispatchActionConfig?
  getter focus_on_load : Bool?
  getter placeholder : Slack::UI::CompositionObjects::PlainText?

  def initialize(
    *,
    @action_id : String? = nil,
    @initial_value : String? = nil,
    @dispatch_action_config : Slack::UI::CompositionObjects::DispatchActionConfig? = nil,
    @focus_on_load : Bool? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
  )
    validate!
  end

  def type : String
    "url_text_input"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "#{type}.placeholder.too_long", "placeholder.text")
    end
    if config = @dispatch_action_config
      config.validate.each { |issue| issues << issue.at("dispatch_action_config") }
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "initial_value", @initial_value if @initial_value
      json.field "dispatch_action_config", @dispatch_action_config if @dispatch_action_config
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
      json.field "placeholder", @placeholder if @placeholder
    end
  end
end
