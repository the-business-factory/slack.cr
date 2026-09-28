# Multiple checkbox choices in Section, Actions, or Input blocks.
struct Slack::UI::Checked::BlockElements::Checkboxes
  include Slack::UI::Checked::ValueValidation

  alias Option = Slack::UI::Checked::CompositionObjects::CheckboxOption

  @options : Array(Option)
  @initial_options : Array(Option)?
  getter action_id : String?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(*, options : Enumerable(T), initial_options : Enumerable(U)? = nil,
                 @action_id : String? = nil,
                 @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil,
                 @focus_on_load : Bool? = nil) forall T, U
    @options = [] of Option
    options.each { |option| @options << option }
    @initial_options = if initial_options
                         copied = [] of Option
                         initial_options.each { |option| copied << option }
                         copied
                       end
    validate!
  end

  def type : String
    "checkboxes"
  end

  def options : Array(Option)
    @options.dup
  end

  def initial_options : Array(Option)?
    @initial_options.try(&.dup)
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @options.empty? || @options.size > 10
      issues << Slack::UI::Checked::ValidationIssue.new("checkboxes.options.size", "options", "Supply one to ten options.")
    end
    values = Set(String).new
    @options.each_with_index do |option, index|
      option.validate.each { |issue| issues << issue.at("options[#{index}]") }
      unless values.add?(option.value)
        issues << Slack::UI::Checked::ValidationIssue.new("checkboxes.options.value.duplicate", "options[#{index}].value", "Option values must be unique within the checkbox group.")
      end
    end
    if initial = @initial_options
      selected = Set(String).new
      initial.each_with_index do |option, index|
        option.validate.each { |issue| issues << issue.at("initial_options[#{index}]") }
        unless @options.includes?(option)
          issues << Slack::UI::Checked::ValidationIssue.new("checkboxes.initial_option.not_found", "initial_options[#{index}]", "Initial option must exactly match an available option.")
        end
        unless selected.add?(option.value)
          issues << Slack::UI::Checked::ValidationIssue.new("checkboxes.initial_options.duplicate", "initial_options[#{index}]", "Initial selections must be distinct.")
        end
      end
    end
    length_issue(issues, @action_id, 255, "checkboxes.action_id.too_long", "action_id")
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
      json.field "initial_options", @initial_options if @initial_options
      json.field "action_id", @action_id if @action_id
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end
end
