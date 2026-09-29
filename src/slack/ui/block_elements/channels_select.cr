struct Slack::UI::BlockElements::ChannelsSelect
  include Slack::UI::ValueValidation

  getter action_id : String?
  getter initial_channel : String?
  getter placeholder : Slack::UI::CompositionObjects::PlainText?
  getter confirm : Slack::UI::CompositionObjects::Confirmation?
  getter response_url_enabled : Bool?
  getter focus_on_load : Bool?

  def initialize(
    *,
    action_id : (String | Slack::UI::ActionId)? = nil,
    @initial_channel : String? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
    @response_url_enabled : Bool? = nil,
  )
    @action_id = Slack::UI::ActionId.value_of(action_id)
    validate!
  end

  def type : String
    "channels_select"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "#{type}.placeholder.too_long", "placeholder.text")
    end
    if confirm = @confirm
      confirm.validate.each { |issue| issues << issue.at("confirm") }
    end
    if @initial_channel.try(&.empty?)
      issues << Slack::UI::ValidationIssue.new("#{type}.initial_channel.empty", "initial_channel", "Initial channel ID must not be empty.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "initial_channel", @initial_channel if @initial_channel
      json.field "placeholder", @placeholder if @placeholder
      json.field "confirm", @confirm if @confirm
      json.field "response_url_enabled", @response_url_enabled unless @response_url_enabled.nil?
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
