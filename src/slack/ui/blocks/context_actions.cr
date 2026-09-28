# Feedback buttons and icon buttons for a message. Slack lists messages as the
# only surface, so only `MessageSourceBlock` includes it.
struct Slack::UI::Blocks::ContextActions
  include Slack::UI::ValueValidation

  alias Element = Slack::UI::BlockElements::FeedbackButtons | Slack::UI::BlockElements::IconButton

  ELEMENTS_MAX_SIZE = 5

  @elements : Array(Element)
  getter block_id : String?

  def initialize(elements : Enumerable(T), @block_id : String? = nil) forall T
    @elements = [] of Element
    elements.each { |element| append_element(element) }
    validate!
  end

  def type : String
    "context_actions"
  end

  def elements : Array(Element)
    @elements.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    if @elements.empty?
      issues << ValidationIssue.new("context_actions.elements.empty", "elements", "Elements must contain at least one element.")
    elsif @elements.size > ELEMENTS_MAX_SIZE
      issues << ValidationIssue.new("context_actions.elements.too_many", "elements", "Elements cannot contain more than #{ELEMENTS_MAX_SIZE} elements.")
    end
    action_ids = Set(String).new
    @elements.each_with_index do |element, index|
      element.validate.each { |issue| issues << issue.at("elements[#{index}]") }
      action_id = element.action_id
      if action_id && !action_ids.add?(action_id)
        issues << ValidationIssue.new("context_actions.action_id.duplicate", "elements[#{index}].action_id",
          "Action IDs must be unique within a context actions block.")
      end
    end
    length_issue(issues, @block_id, 255, "context_actions.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
      json.field "elements", @elements
    end
  end

  private def append_element(element : Element) : Nil
    @elements << element
  end
end
