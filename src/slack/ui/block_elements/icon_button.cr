# A button with an icon. Slack supports this element only in a
# `Blocks::ContextActions` block.
struct Slack::UI::BlockElements::IconButton
  include Slack::UI::ValueValidation

  getter icon : IconButtonIcon
  getter text : CompositionObjects::PlainText
  getter action_id : String?
  getter value : String?
  getter confirm : CompositionObjects::Confirmation?
  getter accessibility_label : String?
  @visible_to_user_ids : Array(String)?

  # Without *visible_to_user_ids*, Slack shows the button to all users.
  def initialize(
    @icon : IconButtonIcon,
    *,
    @text : CompositionObjects::PlainText,
    action_id : (String | Slack::UI::ActionId)? = nil,
    @value : String? = nil,
    @confirm : CompositionObjects::Confirmation? = nil,
    @accessibility_label : String? = nil,
    visible_to_user_ids : Enumerable(T)? = nil,
  ) forall T
    @action_id = Slack::UI::ActionId.value_of(action_id)
    @visible_to_user_ids = if visible_to_user_ids
                             user_ids = [] of String
                             visible_to_user_ids.each { |user_id| append_user_id(user_ids, user_id) }
                             user_ids
                           end
    validate!
  end

  def type : String
    "icon_button"
  end

  def visible_to_user_ids : Array(String)?
    @visible_to_user_ids.try(&.dup)
  end

  def validate : Array(ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    length_issue(issues, @text.text, 75, "icon_button.text.too_long", "text.text")
    length_issue(issues, @action_id, 255, "icon_button.action_id.too_long", "action_id")
    length_issue(issues, @value, 2000, "icon_button.value.too_long", "value")
    length_issue(issues, @accessibility_label, 75, "icon_button.accessibility_label.too_long", "accessibility_label")
    @confirm.try(&.validate.each { |issue| issues << issue.at("confirm") })
    visibility_issues(issues)
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "icon", @icon.wire_value
      json.field "text", @text
      json.field "action_id", @action_id if @action_id
      json.field "value", @value if @value
      json.field "confirm", @confirm if @confirm
      json.field "accessibility_label", @accessibility_label if @accessibility_label
      json.field "visible_to_user_ids", @visible_to_user_ids if @visible_to_user_ids
    end
  end

  private def append_user_id(user_ids : Array(String), user_id : String) : Nil
    user_ids << user_id
  end

  # Library policy: an empty list or ID would hide the button from everyone,
  # so omit the field to show it to all users.
  private def visibility_issues(issues : Array(ValidationIssue)) : Nil
    user_ids = @visible_to_user_ids
    return unless user_ids

    if user_ids.empty?
      issues << ValidationIssue.new("icon_button.visible_to_user_ids.empty", "visible_to_user_ids",
        "Visible user IDs must contain at least one ID. Omit the field to show the button to all users.")
    elsif index = user_ids.index(&.empty?)
      issues << ValidationIssue.new("icon_button.visible_to_user_ids.blank", "visible_to_user_ids[#{index}]", "User IDs must not be empty.")
    end
  end
end
