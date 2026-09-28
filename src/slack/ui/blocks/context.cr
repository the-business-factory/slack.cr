alias Slack::UI::Blocks::ContextElement = Slack::UI::CompositionObjects::Text | Slack::UI::BlockElements::Image

struct Slack::UI::Blocks::Context
  include Slack::UI::ValueValidation

  @elements : Array(ContextElement)
  getter block_id : String?

  def initialize(elements : Enumerable(T), @block_id : String? = nil) forall T
    @elements = [] of ContextElement
    elements.each { |element| append_element(element) }
    validate!
  end

  def type : String
    "context"
  end

  def elements : Array(ContextElement)
    @elements.dup
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @elements.empty?
      issues << Slack::UI::ValidationIssue.new("context.elements.empty", "elements", "Context must contain at least one element.")
    elsif @elements.size > 10
      issues << Slack::UI::ValidationIssue.new("context.elements.too_many", "elements", "Context cannot contain more than 10 elements.")
    end
    @elements.each_with_index do |element, index|
      element.validate.each { |issue| issues << issue.at("elements[#{index}]") }
    end
    length_issue(issues, @block_id, 255, "context.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "elements", @elements
      json.field "block_id", @block_id if @block_id
    end
  end

  private def append_element(element : ContextElement) : Nil
    @elements << element
  end
end
