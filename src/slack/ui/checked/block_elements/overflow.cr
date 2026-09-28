# A compact menu for actions and links in Section and Actions blocks.
struct Slack::UI::Checked::BlockElements::Overflow
  include Slack::UI::Checked::ValueValidation

  alias Option = Slack::UI::Checked::CompositionObjects::OverflowOption

  @options : Array(Option)
  getter action_id : String?
  getter confirm : Slack::UI::Checked::CompositionObjects::Confirmation?

  def initialize(*, options : Enumerable(T), @action_id : String? = nil,
                 @confirm : Slack::UI::Checked::CompositionObjects::Confirmation? = nil) forall T
    @options = [] of Option
    options.each { |option| @options << option }
    validate!
  end

  def type : String
    "overflow"
  end

  def options : Array(Option)
    @options.dup
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @options.empty? || @options.size > 5
      issues << Slack::UI::Checked::ValidationIssue.new("overflow.options.size", "options", "Supply one to five options.")
    end
    values = Set(String).new
    @options.each_with_index do |option, index|
      option.validate.each { |issue| issues << issue.at("options[#{index}]") }
      unless values.add?(option.value)
        issues << Slack::UI::Checked::ValidationIssue.new("overflow.options.value.duplicate", "options[#{index}].value", "Option values must be unique within the menu.")
      end
    end
    length_issue(issues, @action_id, 255, "overflow.action_id.too_long", "action_id")
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
      json.field "action_id", @action_id if @action_id
      json.field "confirm", @confirm if @confirm
    end
  end
end
