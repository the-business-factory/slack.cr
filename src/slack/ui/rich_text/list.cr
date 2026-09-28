# A bullet or ordered list. Each item is a Section; nest lists with `indent`.
struct Slack::UI::RichText::List
  include NodeValidation

  @elements : Array(Section)
  getter style : ListStyle
  getter indent : Int32?
  getter offset : Int32?
  getter border : Int32?

  def initialize(@style : ListStyle, elements : Enumerable(T), @indent : Int32? = nil, @offset : Int32? = nil, @border : Int32? = nil) forall T
    @elements = [] of Section
    elements.each { |element| append_element(element) }
    validate!
  end

  def type : String
    "rich_text_list"
  end

  def elements : Array(Section)
    @elements.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    children_issues(issues, @elements, "rich_text_list.elements.empty")
    {"indent" => @indent, "offset" => @offset}.each do |field, value|
      if value && value < 0
        issues << ValidationIssue.new("rich_text_list.#{field}.negative", field, "Value must not be negative.")
      end
    end
    border_issue(issues, @border, "rich_text_list.border.invalid")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "style", @style.wire_value
      json.field "elements", @elements
      json.field "indent", @indent if @indent
      json.field "offset", @offset if @offset
      json.field "border", @border if @border
    end
  end

  private def append_element(element : Section) : Nil
    @elements << element
  end
end
