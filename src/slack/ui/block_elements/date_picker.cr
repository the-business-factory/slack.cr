struct Slack::UI::BlockElements::DatePicker
  include Slack::UI::ValueValidation

  getter action_id : String?
  getter initial_date : String?
  getter placeholder : Slack::UI::CompositionObjects::PlainText?
  getter confirm : Slack::UI::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @action_id : String? = nil,
    @initial_date : String? = nil,
    @placeholder : Slack::UI::CompositionObjects::PlainText? = nil,
    @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  )
    validate!
  end

  def type : String
    "datepicker"
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
    if (date = @initial_date) && !valid_date?(date)
      issues << Slack::UI::ValidationIssue.new("#{type}.initial_date.invalid", "initial_date", "Initial date must be a valid YYYY-MM-DD calendar date (years 0001–9999).")
    end
    issues
  end

  private def valid_date?(date : String) : Bool
    return false unless /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/.matches?(date)
    year = date[0, 4].to_i
    month = date[5, 2].to_i
    day = date[8, 2].to_i
    return false unless year >= 1 && (1..12).includes?(month)
    (1..Time.days_in_month(year, month)).includes?(day)
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "initial_date", @initial_date if @initial_date
      json.field "placeholder", @placeholder if @placeholder
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
