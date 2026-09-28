# Multiple-choice menu whose options Slack loads from the app's Options Load
# URL. Initial options cannot be checked against remote results; they must be
# distinct, nonempty when supplied, and within max_selected_items.
struct Slack::UI::Checked::BlockElements::MultiExternalSelect
  include Slack::UI::Checked::ValueValidation

  @initial_options : Array(Slack::UI::Checked::CompositionObjects::Option)?
  getter action_id : String?
  getter placeholder : Slack::UI::Checked::CompositionObjects::PlainText?
  getter min_query_length : Int32?
  getter max_selected_items : Int32?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?
  getter focus_on_load : Bool?

  def initialize(
    *,
    @action_id : String? = nil,
    @placeholder : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    initial_options : Enumerable(T)? = nil,
    @min_query_length : Int32? = nil,
    @max_selected_items : Int32? = nil,
    @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil,
    @focus_on_load : Bool? = nil,
  ) forall T
    @initial_options = Slack::UI::Checked::OptionCollection.copy(initial_options)
    validate!
  end

  def type : String
    "multi_external_select"
  end

  def initial_options : Array(Slack::UI::Checked::CompositionObjects::Option)?
    @initial_options.try(&.dup)
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    length_issue(issues, @action_id, 255, "#{type}.action_id.too_long", "action_id")
    if placeholder = @placeholder
      placeholder.validate.each { |issue| issues << issue.at("placeholder") }
      length_issue(issues, placeholder.text, 150, "#{type}.placeholder.too_long", "placeholder.text")
    end
    if (minimum = @min_query_length) && minimum < 0
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.min_query_length.negative", "min_query_length", "Minimum query length cannot be negative.")
    end
    if (maximum = @max_selected_items) && maximum < 1
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.max_selected_items.too_small", "max_selected_items", "Maximum selected items must be at least one.")
    end
    if initial = @initial_options
      validate_initial(initial, issues)
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
      json.field "initial_options", @initial_options if @initial_options
      json.field "min_query_length", @min_query_length if @min_query_length
      json.field "max_selected_items", @max_selected_items if @max_selected_items
      json.field "confirm", @confirm if @confirm
      json.field "focus_on_load", @focus_on_load unless @focus_on_load.nil?
    end
  end

  private def validate_initial(initial : Array(Slack::UI::Checked::CompositionObjects::Option), issues : Array(Slack::UI::Checked::ValidationIssue)) : Nil
    if initial.empty?
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_options.empty", "initial_options", "Initial options must contain at least one option when supplied.")
    end
    if (maximum = @max_selected_items) && initial.size > maximum
      issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_options.too_many", "initial_options", "Initial selections cannot exceed maximum selected items.")
    end
    values = Set(String).new
    initial.each_with_index do |option, index|
      option.validate.each { |issue| issues << issue.at("initial_options[#{index}]") }
      unless values.add?(option.value)
        issues << Slack::UI::Checked::ValidationIssue.new("#{type}.initial_options.duplicate", "initial_options[#{index}]", "Initial selections must be distinct.")
      end
    end
  end
end
