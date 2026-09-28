alias Slack::UI::RichText::Element = Slack::UI::RichText::Text |
                                     Slack::UI::RichText::Link |
                                     Slack::UI::RichText::Emoji |
                                     Slack::UI::RichText::User |
                                     Slack::UI::RichText::Usergroup |
                                     Slack::UI::RichText::Channel |
                                     Slack::UI::RichText::Broadcast |
                                     Slack::UI::RichText::Date |
                                     Slack::UI::RichText::Color |
                                     Slack::UI::RichText::Team |
                                     Slack::UI::RichText::File |
                                     Slack::UI::RichText::Canvas |
                                     Slack::UI::RichText::WorkflowMention

# A run of inline rich text elements. It is also the only item type of a list.
struct Slack::UI::RichText::Section
  include NodeValidation

  @elements : Array(Element)

  def initialize(elements : Enumerable(T)) forall T
    @elements = [] of Element
    elements.each { |element| append_element(element) }
    validate!
  end

  def type : String
    "rich_text_section"
  end

  def elements : Array(Element)
    @elements.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    children_issues(issues, @elements, "rich_text_section.elements.empty")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "elements", @elements
    end
  end

  private def append_element(element : Element) : Nil
    @elements << element
  end
end
