struct Slack::UI::RichText::Quote
  include NodeValidation

  @elements : Array(Element)
  getter border : Int32?

  def initialize(elements : Enumerable(T), @border : Int32? = nil) forall T
    @elements = [] of Element
    elements.each { |element| append_element(element) }
    validate!
  end

  def type : String
    "rich_text_quote"
  end

  def elements : Array(Element)
    @elements.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    children_issues(issues, @elements, "rich_text_quote.elements.empty")
    border_issue(issues, @border, "rich_text_quote.border.invalid")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "elements", @elements
      json.field "border", @border if @border
    end
  end

  private def append_element(element : Element) : Nil
    @elements << element
  end
end
