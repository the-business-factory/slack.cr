alias Slack::UI::Checked::RichText::Element = Slack::UI::Checked::RichText::Text |
                                              Slack::UI::Checked::RichText::Link |
                                              Slack::UI::Checked::RichText::Emoji |
                                              Slack::UI::Checked::RichText::User |
                                              Slack::UI::Checked::RichText::Usergroup |
                                              Slack::UI::Checked::RichText::Channel |
                                              Slack::UI::Checked::RichText::Broadcast |
                                              Slack::UI::Checked::RichText::Date |
                                              Slack::UI::Checked::RichText::Color |
                                              Slack::UI::Checked::RichText::Team |
                                              Slack::UI::Checked::RichText::File |
                                              Slack::UI::Checked::RichText::Canvas |
                                              Slack::UI::Checked::RichText::WorkflowMention

# A run of inline rich text elements. It is also the only item type of a list.
struct Slack::UI::Checked::RichText::Section
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
