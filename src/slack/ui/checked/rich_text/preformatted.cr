alias Slack::UI::Checked::RichText::PreformattedElement = Slack::UI::Checked::RichText::Text | Slack::UI::Checked::RichText::Link

# A code block. Slack documents only text and link children.
struct Slack::UI::Checked::RichText::Preformatted
  include NodeValidation

  @elements : Array(PreformattedElement)
  getter border : Int32?
  getter language : String?

  def initialize(elements : Enumerable(T), @border : Int32? = nil, @language : String? = nil) forall T
    @elements = [] of PreformattedElement
    elements.each { |element| append_element(element) }
    validate!
  end

  def type : String
    "rich_text_preformatted"
  end

  def elements : Array(PreformattedElement)
    @elements.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    children_issues(issues, @elements, "rich_text_preformatted.elements.empty")
    border_issue(issues, @border, "rich_text_preformatted.border.invalid")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "elements", @elements
      json.field "border", @border if @border
      json.field "language", @language if @language
    end
  end

  private def append_element(element : PreformattedElement) : Nil
    @elements << element
  end
end
