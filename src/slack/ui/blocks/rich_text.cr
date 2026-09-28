alias Slack::UI::RichText::Container = Slack::UI::RichText::Section |
                                       Slack::UI::RichText::List |
                                       Slack::UI::RichText::Preformatted |
                                       Slack::UI::RichText::Quote

# Formatted display text. Containers hold inline elements; a list holds sections.
struct Slack::UI::Blocks::RichText
  include Slack::UI::ValueValidation

  @elements : Array(Slack::UI::RichText::Container)
  getter block_id : String?

  def initialize(elements : Enumerable(T), @block_id : String? = nil) forall T
    @elements = [] of Slack::UI::RichText::Container
    elements.each { |element| append_element(element) }
    validate!
  end

  def type : String
    "rich_text"
  end

  def elements : Array(Slack::UI::RichText::Container)
    @elements.dup
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @elements.empty?
      issues << Slack::UI::ValidationIssue.new("rich_text.elements.empty", "elements", "Rich text must contain at least one element.")
    end
    @elements.each_with_index do |element, index|
      element.validate.each { |issue| issues << issue.at("elements[#{index}]") }
    end
    length_issue(issues, @block_id, 255, "rich_text.block_id.too_long", "block_id")
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

  private def append_element(element : Slack::UI::RichText::Container) : Nil
    @elements << element
  end
end
