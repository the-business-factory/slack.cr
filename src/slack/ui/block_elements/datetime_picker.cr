# Chooses one instant. Slack documents it for messages and modals, not Home.
struct Slack::UI::Checked::BlockElements::DatetimePicker
  include Slack::UI::Checked::ValueValidation

  # Slack documents initial_date_time as a ten-digit Unix timestamp in seconds.
  INITIAL_UNIX_SECONDS = 1_000_000_000_i64..9_999_999_999_i64

  getter action_id : String?
  # Sent as whole Unix seconds; sub-second precision is dropped.
  getter initial_date_time : Time?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @action_id : String? = nil,
    @initial_date_time : Time? = nil,
    @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  )
    validate!
  end

  def type : String
    "datetimepicker"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if confirm = @confirm
      confirm.validate.each { |issue| issues << issue.at("confirm") }
    end
    if (time = @initial_date_time) && !INITIAL_UNIX_SECONDS.includes?(time.to_unix)
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_date_time.invalid", "initial_date_time",
        "Initial date and time must be a ten-digit Unix timestamp in seconds (2001-09-09 through 2286-11-20 UTC).")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      if time = @initial_date_time
        json.field "initial_date_time", time.to_unix
      end
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
