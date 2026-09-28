struct Slack::UI::Checked::BlockElements::UsersSelect
  include Slack::UI::Checked::ValueValidation

  getter action_id : String?
  getter initial_user : String?
  getter placeholder : Slack::UI::Checked::CompositionObjects::PlainText?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @action_id : String? = nil,
    @initial_user : String? = nil,
    @placeholder : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  )
    validate!
  end

  def type : String
    "users_select"
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
    if @initial_user.try(&.empty?)
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_user.empty", "initial_user", "Initial user ID must not be empty.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "initial_user", @initial_user if @initial_user
      json.field "placeholder", @placeholder if @placeholder
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
