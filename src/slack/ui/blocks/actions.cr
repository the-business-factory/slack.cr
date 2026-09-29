struct Slack::UI::Blocks::Actions
  include Slack::UI::ValueValidation

  alias Element = Slack::UI::BlockElements::Button | Slack::UI::BlockElements::StaticSelect | Slack::UI::BlockElements::MultiStaticSelect | Slack::UI::BlockElements::ExternalSelect | Slack::UI::BlockElements::MultiExternalSelect | Slack::UI::BlockElements::Checkboxes | Slack::UI::BlockElements::RadioButtons | Slack::UI::BlockElements::UsersSelect | Slack::UI::BlockElements::MultiUsersSelect | Slack::UI::BlockElements::ConversationsSelect | Slack::UI::BlockElements::MultiConversationsSelect | Slack::UI::BlockElements::DatePicker | Slack::UI::BlockElements::TimePicker | Slack::UI::BlockElements::DatetimePicker | Slack::UI::BlockElements::ChannelsSelect | Slack::UI::BlockElements::MultiChannelsSelect | Slack::UI::BlockElements::Overflow | Slack::UI::BlockElements::WorkflowButton

  ELEMENTS_MAX_SIZE   =  25
  BLOCK_ID_MAX_LENGTH = 255

  @elements : Array(Element)

  getter block_id : String?

  def initialize(elements : Enumerable(T), @block_id : String? = nil) forall T
    @elements = copy_elements(elements)
    validate!
  end

  def type : String
    "actions"
  end

  def elements : Array(Element)
    @elements.dup
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @elements.empty?
      issues << Slack::UI::ValidationIssue.new(
        code: "actions.elements.empty",
        path: "elements",
        message: "Elements must contain at least one element."
      )
    elsif @elements.size > ELEMENTS_MAX_SIZE
      issues << Slack::UI::ValidationIssue.new(
        code: "actions.elements.too_many",
        path: "elements",
        message: "Elements cannot contain more than #{ELEMENTS_MAX_SIZE} elements."
      )
    end

    action_ids = {} of String => Int32
    @elements.each_with_index do |element, index|
      element.validate.each { |issue| issues << issue.at("elements[#{index}]") }
      issues.concat(ChannelResponseUrl.validate(element, "elements[#{index}].response_url_enabled"))
      if action_id = element.action_id
        if action_ids.has_key?(action_id)
          issues << Slack::UI::ValidationIssue.new(
            code: "actions.action_id.duplicate",
            path: "elements[#{index}].action_id",
            message: "Action IDs must be unique within an actions block."
          )
        else
          action_ids[action_id] = index
        end
      end
    end

    length_issue(issues, @block_id, BLOCK_ID_MAX_LENGTH, "actions.block_id.too_long", "block_id", "Block ID")
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

  private def copy_elements(elements : Enumerable(T)) : Array(Element) forall T
    copied = [] of Element
    elements.each { |element| append_element(copied, element) }
    copied
  end

  private def append_element(elements : Array(Element), element : Element) : Nil
    elements << element
  end
end
