struct Slack::UI::BlockElements::ConversationsSelect
  include Slack::UI::ValueValidation

  getter filter : Slack::UI::CompositionObjects::ConversationFilter?
  getter default_to_current_conversation : Bool?
  getter action_id : String?
  getter initial_conversation : String?
  getter placeholder : Slack::UI::CompositionObjects::PlainText?
  getter confirm : Slack::UI::CompositionObjects::Confirmation?
  getter response_url_enabled : Bool?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @filter : Slack::UI::CompositionObjects::ConversationFilter? = nil,
    @default_to_current_conversation : Bool? = nil,
    @action_id : String? = nil,
    @initial_conversation : String? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
    @response_url_enabled : Bool? = nil,
  )
    validate!
  end

  def type : String
    "conversations_select"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "#{type}.placeholder.too_long", "placeholder.text")
    end
    if filter = @filter
      filter.validate.each { |issue| issues << issue.at("filter") }
    end
    if confirm = @confirm
      confirm.validate.each { |issue| issues << issue.at("confirm") }
    end
    if @initial_conversation.try(&.empty?)
      issues << Slack::UI::ValidationIssue.new("#{type}.initial_conversation.empty", "initial_conversation", "Initial conversation ID must not be empty.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "filter", @filter if @filter
      json.field "default_to_current_conversation", @default_to_current_conversation unless @default_to_current_conversation.nil?
      json.field "action_id", @action_id if @action_id
      json.field "initial_conversation", @initial_conversation if @initial_conversation
      json.field "placeholder", @placeholder if @placeholder
      json.field "confirm", @confirm if @confirm
      json.field "response_url_enabled", @response_url_enabled unless @response_url_enabled.nil?
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
