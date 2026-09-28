struct Slack::UI::Checked::BlockElements::TimePicker
  include Slack::UI::Checked::ValueValidation

  getter action_id : String?
  getter initial_time : String?
  getter timezone : String?
  getter placeholder : Slack::UI::Checked::CompositionObjects::PlainText?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @action_id : String? = nil,
    @initial_time : String? = nil,
    @timezone : String? = nil,
    @placeholder : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  )
    validate!
  end

  def type : String
    "timepicker"
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
    if (time = @initial_time) && !/\A(?:[01][0-9]|2[0-3]):[0-5][0-9]\z/.matches?(time)
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_time.invalid", "initial_time", "Initial time must use HH:mm from 00:00 through 23:59.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "initial_time", @initial_time if @initial_time
      json.field "timezone", @timezone if @timezone
      json.field "placeholder", @placeholder if @placeholder
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
