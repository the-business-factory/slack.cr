struct Slack::UI::BlockElements::MultiConversationsSelect
  include Slack::UI::ValueValidation

  @initial_conversations : Array(String)?
  getter filter : Slack::UI::CompositionObjects::ConversationFilter?
  getter default_to_current_conversation : Bool?
  getter action_id : String?
  getter max_selected_items : Int32?
  getter placeholder : Slack::UI::CompositionObjects::PlainText?
  getter confirm : Slack::UI::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @filter : Slack::UI::CompositionObjects::ConversationFilter? = nil,
    @default_to_current_conversation : Bool? = nil,
    @action_id : String? = nil,
    initial_conversations : Enumerable(T)? = nil,
    @max_selected_items : Int32? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  ) forall T
    @initial_conversations = if initial_conversations
                               copied = [] of String
                               initial_conversations.each { |conversation| copied << conversation }
                               copied
                             end
    validate!
  end

  def type : String
    "multi_conversations_select"
  end

  def initial_conversations : Array(String)?
    @initial_conversations.try(&.dup)
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
    if maximum = @max_selected_items
      if maximum < 1
        issues << Slack::UI::ValidationIssue.new("#{type}.max_selected_items.too_small", "max_selected_items", "Maximum selected items must be at least one.")
      end
    end
    if initial = @initial_conversations
      if initial.empty?
        issues << Slack::UI::ValidationIssue.new("#{type}.initial_conversations.empty", "initial_conversations", "Initial conversations must contain at least one ID when supplied.")
      end
      if maximum = @max_selected_items
        if initial.size > maximum
          issues << Slack::UI::ValidationIssue.new("#{type}.initial_conversations.too_many", "initial_conversations", "Initial selections cannot exceed maximum selected items.")
        end
      end
      conversations = Set(String).new
      initial.each_with_index do |conversation, index|
        if conversation.empty?
          issues << Slack::UI::ValidationIssue.new("#{type}.initial_conversations.empty", "initial_conversations[#{index}]", "Initial conversation ID must not be empty.")
        end
        unless conversations.add?(conversation)
          issues << Slack::UI::ValidationIssue.new("#{type}.initial_conversations.duplicate", "initial_conversations[#{index}]", "Initial selections must be distinct.")
        end
      end
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
      json.field "initial_conversations", @initial_conversations if @initial_conversations
      json.field "max_selected_items", @max_selected_items if @max_selected_items
      json.field "placeholder", @placeholder if @placeholder
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
