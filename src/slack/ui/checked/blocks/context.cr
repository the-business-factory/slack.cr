alias Slack::UI::Checked::Blocks::ContextElement = Slack::UI::Checked::CompositionObjects::Text | Slack::UI::Checked::BlockElements::Image

struct Slack::UI::Checked::Blocks::Context
  include Slack::UI::Checked::ValueValidation

  @elements : Array(ContextElement)
  getter block_id : String?

  def initialize(elements : Enumerable(T), @block_id : String? = nil) forall T
    Slack::UI::Checked::DeclaredTypes.context_element(T)
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

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @elements.empty?
      issues << Slack::UI::Checked::ValidationIssue.new("context.elements.empty", "elements", "Context must contain at least one element.")
    elsif @elements.size > 10
      issues << Slack::UI::Checked::ValidationIssue.new("context.elements.too_many", "elements", "Context cannot contain more than 10 elements.")
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
