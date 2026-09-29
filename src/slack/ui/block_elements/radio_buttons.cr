# A single radio choice in Section, Actions, or Input blocks.
struct Slack::UI::BlockElements::RadioButtons
  include Slack::UI::ValueValidation

  alias Option = Slack::UI::CompositionObjects::RadioOption

  @options : Array(Option)
  getter initial_option : Option?
  getter action_id : String?
  getter confirm : Slack::UI::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(*, options : Enumerable(T), @initial_option : Option? = nil,
                 action_id : (String | Slack::UI::ActionId)? = nil,
                 @confirm : Slack::UI::CompositionObjects::Confirmation? = nil,
                 @focus_on_load : Bool? = nil) forall T
    @action_id = Slack::UI::ActionId.value_of(action_id)
    @options = [] of Option
    options.each { |option| @options << option }
    validate!
  end

  def type : String
    "radio_buttons"
  end

  def options : Array(Option)
    @options.dup
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @options.empty? || @options.size > 10
      issues << Slack::UI::ValidationIssue.new("radio_buttons.options.size", "options", "Supply one to ten options.")
    end
    values = Set(String).new
    @options.each_with_index do |option, index|
      option.validate.each { |issue| issues << issue.at("options[#{index}]") }
      unless values.add?(option.value)
        issues << Slack::UI::ValidationIssue.new("radio_buttons.options.value.duplicate", "options[#{index}].value", "Option values must be unique within the radio group.")
      end
    end
    if initial = @initial_option
      initial.validate.each { |issue| issues << issue.at("initial_option") }
      unless @options.includes?(initial)
        issues << Slack::UI::ValidationIssue.new("radio_buttons.initial_option.not_found", "initial_option", "Initial option must exactly match an available option.")
      end
    end
    length_issue(issues, @action_id, 255, "radio_buttons.action_id.too_long", "action_id")
    if confirmation = @confirm
      confirmation.validate.each { |issue| issues << issue.at("confirm") }
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "options", @options
      json.field "initial_option", @initial_option if @initial_option
      json.field "action_id", @action_id if @action_id
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
