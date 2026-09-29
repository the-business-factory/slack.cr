struct Slack::UI::BlockElements::MultiUsersSelect
  include Slack::UI::ValueValidation

  @initial_users : Array(String)?
  getter action_id : String?
  getter max_selected_items : Int32?
  getter placeholder : Slack::UI::CompositionObjects::PlainText?
  getter confirm : Slack::UI::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    action_id : (String | Slack::UI::ActionId)? = nil,
    initial_users : Enumerable(T)? = nil,
    @max_selected_items : Int32? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  ) forall T
    @action_id = Slack::UI::ActionId.value_of(action_id)
    @initial_users = if initial_users
                       copied = [] of String
                       initial_users.each { |user| copied << user }
                       copied
                     end
    validate!
  end

  def type : String
    "multi_users_select"
  end

  def initial_users : Array(String)?
    @initial_users.try(&.dup)
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
    if maximum = @max_selected_items
      if maximum < 1
        issues << Slack::UI::ValidationIssue.new("#{type}.max_selected_items.too_small", "max_selected_items", "Maximum selected items must be at least one.")
      end
    end
    if initial = @initial_users
      if maximum = @max_selected_items
        if initial.size > maximum
          issues << Slack::UI::ValidationIssue.new("#{type}.initial_users.too_many", "initial_users", "Initial selections cannot exceed maximum selected items.")
        end
      end
      users = Set(String).new
      initial.each_with_index do |user, index|
        if user.empty?
          issues << Slack::UI::ValidationIssue.new("#{type}.initial_users.empty", "initial_users[#{index}]", "Initial user ID must not be empty.")
        end
        unless users.add?(user)
          issues << Slack::UI::ValidationIssue.new("#{type}.initial_users.duplicate", "initial_users[#{index}]", "Initial selections must be distinct.")
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
      json.field "initial_users", @initial_users if @initial_users
      json.field "max_selected_items", @max_selected_items if @max_selected_items
      json.field "placeholder", @placeholder if @placeholder
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
