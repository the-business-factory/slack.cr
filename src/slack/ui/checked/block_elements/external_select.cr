# Menu whose options Slack loads from the app's Options Load URL through
# `block_suggestion` requests. The initial option cannot be checked against
# remote results, so only its own option limits apply here.
struct Slack::UI::Checked::BlockElements::ExternalSelect
  include Slack::UI::Checked::ValueValidation

  getter action_id : String?
  getter placeholder : Slack::UI::Checked::CompositionObjects::PlainText?
  getter initial_option : Slack::UI::Checked::CompositionObjects::Option?
  getter min_query_length : Int32?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @action_id : String? = nil,
    @placeholder : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @initial_option : Slack::UI::Checked::CompositionObjects::Option? = nil,
    @min_query_length : Int32? = nil,
    @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  )
    validate!
  end

  def type : String
    "external_select"
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "#{type}.placeholder.too_long", "placeholder.text")
    end
    if initial = @initial_option
      initial.validate.each { |issue| issues << issue.at("initial_option") }
    end
    if (minimum = @min_query_length) && minimum < 0
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.min_query_length.negative", "min_query_length", "Minimum query length cannot be negative.")
    end
    if confirm = @confirm
      confirm.validate.each { |issue| issues << issue.at("confirm") }
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "action_id", @action_id if @action_id
      json.field "placeholder", @placeholder if @placeholder
      json.field "initial_option", @initial_option if @initial_option
      json.field "min_query_length", @min_query_length if @min_query_length
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
