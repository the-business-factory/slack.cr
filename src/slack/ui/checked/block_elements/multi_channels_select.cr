struct Slack::UI::Checked::BlockElements::MultiChannelsSelect
  include Slack::UI::Checked::ValueValidation

  @initial_channels : Array(String)?
  getter action_id : String?
  getter max_selected_items : Int32?
  getter placeholder : Slack::UI::Checked::CompositionObjects::PlainText?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @action_id : String? = nil,
    initial_channels : Enumerable(T)? = nil,
    @max_selected_items : Int32? = nil,
    @placeholder : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  ) forall T
    @initial_channels = if initial_channels
                          copied = [] of String
                          initial_channels.each { |channel| copied << channel }
                          copied
                        end
    validate!
  end

  def type : String
    "multi_channels_select"
  end

  def initial_channels : Array(String)?
    @initial_channels.try(&.dup)
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "#{type}.placeholder.too_long", "placeholder.text")
    end
    if confirm = @confirm
      confirm.validate.each { |issue| issues << issue.at("confirm") }
    end
    if maximum = @max_selected_items
      if maximum < 1
        issues << Slack::UI::Checked::ValidationIssue.new("#{type}.max_selected_items.too_small", "max_selected_items", "Maximum selected items must be at least one.")
      end
    end
    if initial = @initial_channels
      if initial.empty?
        issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_channels.empty", "initial_channels", "Initial channels must contain at least one ID when supplied.")
      end
      if maximum = @max_selected_items
        if initial.size > maximum
          issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_channels.too_many", "initial_channels", "Initial selections cannot exceed maximum selected items.")
        end
      end
      channels = Set(String).new
      initial.each_with_index do |channel, index|
        if channel.empty?
          issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_channels.empty", "initial_channels[#{index}]", "Initial channel ID must not be empty.")
        end
        unless channels.add?(channel)
          issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_channels.duplicate", "initial_channels[#{index}]", "Initial selections must be distinct.")
        end
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "initial_channels", @initial_channels if @initial_channels
      json.field "max_selected_items", @max_selected_items if @max_selected_items
      json.field "placeholder", @placeholder if @placeholder
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
