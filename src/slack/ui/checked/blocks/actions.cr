struct Slack::UI::Checked::Blocks::Actions
  alias Element = Slack::UI::Checked::BlockElements::Button

  ELEMENTS_MAX_SIZE   =  25
  BLOCK_ID_MAX_LENGTH = 255

  @elements : Array(Element)

  getter block_id : String?

  def initialize(elements : Enumerable(T), @block_id : String? = nil) forall T
    Slack::UI::Checked::DeclaredTypes.actions_element(T)
    @elements = copy_elements(elements)
    validate!
  end

  def type : String
    "actions"
  end

  def elements : Array(Element)
    @elements.dup
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @elements.empty?
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "actions.elements.empty",
        path: "elements",
        message: "Elements must contain at least one button."
      )
    elsif @elements.size > ELEMENTS_MAX_SIZE
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "actions.elements.too_many",
        path: "elements",
        message: "Elements cannot contain more than #{ELEMENTS_MAX_SIZE} buttons."
      )
    end

    action_ids = {} of String => Int32
    @elements.each_with_index do |element, index|
      element.validate.each { |issue| issues << issue.at("elements[#{index}]") }
      if action_id = element.action_id
        if action_ids.has_key?(action_id)
          issues << Slack::UI::Checked::ValidationIssue.new(
            code: "actions.action_id.duplicate",
            path: "elements[#{index}].action_id",
            message: "Action IDs must be unique within an actions block."
          )
        else
          action_ids[action_id] = index
        end
      end
    end

    if @block_id.try(&.size.>(BLOCK_ID_MAX_LENGTH))
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "actions.block_id.too_long",
        path: "block_id",
        message: "Block ID cannot be longer than #{BLOCK_ID_MAX_LENGTH} characters."
      )
    end
    issues
  end

  def validate! : Nil
    issues = validate
    raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "elements", @elements
      json.field "block_id", @block_id if @block_id
    end
  end

  private def copy_elements(elements : Enumerable(T)) : Array(Element) forall T
    copied = [] of Element
    elements.each { |element| append_element(copied, element) }
    copied
  end

  private def append_element(elements : Array(Element), element : Element) : Nil
    elements << element
  end
end
