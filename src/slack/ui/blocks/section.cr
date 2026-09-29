struct Slack::UI::Blocks::Section
  include Slack::UI::ValueValidation

  alias Text = Slack::UI::CompositionObjects::Text
  alias Accessory = Slack::UI::BlockElements::Button | Slack::UI::BlockElements::Image | Slack::UI::BlockElements::StaticSelect | Slack::UI::BlockElements::MultiStaticSelect | Slack::UI::BlockElements::ExternalSelect | Slack::UI::BlockElements::MultiExternalSelect | Slack::UI::BlockElements::Checkboxes | Slack::UI::BlockElements::RadioButtons | Slack::UI::BlockElements::UsersSelect | Slack::UI::BlockElements::MultiUsersSelect | Slack::UI::BlockElements::ConversationsSelect | Slack::UI::BlockElements::MultiConversationsSelect | Slack::UI::BlockElements::DatePicker | Slack::UI::BlockElements::TimePicker | Slack::UI::BlockElements::ChannelsSelect | Slack::UI::BlockElements::MultiChannelsSelect | Slack::UI::BlockElements::Overflow | Slack::UI::BlockElements::WorkflowButton

  TEXT_MAX_LENGTH     = 3000
  FIELD_MAX_LENGTH    = 2000
  FIELDS_MAX_SIZE     =   10
  BLOCK_ID_MAX_LENGTH =  255

  @text : Text?
  @fields : Array(Text)?

  getter text : Text?
  getter accessory : Accessory?
  getter block_id : String?
  getter expand : Bool?

  def initialize(
    @text : Text,
    @accessory : Accessory? = nil,
    @block_id : String? = nil,
    @expand : Bool? = nil,
  )
    @fields = nil
    validate!
  end

  def initialize(
    fields : Enumerable(T),
    @accessory : Accessory? = nil,
    @block_id : String? = nil,
    @expand : Bool? = nil,
  ) forall T
    @text = nil
    @fields = copy_fields(fields)
    validate!
  end

  def initialize(
    @text : Text,
    fields : Enumerable(T),
    @accessory : Accessory? = nil,
    @block_id : String? = nil,
    @expand : Bool? = nil,
  ) forall T
    @fields = copy_fields(fields)
    validate!
  end

  def type : String
    "section"
  end

  def fields : Array(Text)?
    @fields.try(&.dup)
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @text.nil? && @fields.nil?
      issues << Slack::UI::ValidationIssue.new(
        code: "section.content.missing",
        path: "section",
        message: "Text or fields must be present."
      )
    end

    if text = @text
      text.validate.each { |issue| issues << issue.at("text") }
      length_issue(issues, text.text, TEXT_MAX_LENGTH, "section.text.too_long", "text.text", "Text")
    end

    if fields = @fields
      if fields.empty?
        issues << Slack::UI::ValidationIssue.new(
          code: "section.fields.empty",
          path: "fields",
          message: "Fields must contain at least one text object."
        )
      elsif fields.size > FIELDS_MAX_SIZE
        issues << Slack::UI::ValidationIssue.new(
          code: "section.fields.too_many",
          path: "fields",
          message: "Fields cannot contain more than #{FIELDS_MAX_SIZE} text objects."
        )
      end

      fields.each_with_index do |field, index|
        field.validate.each { |issue| issues << issue.at("fields[#{index}]") }
        length_issue(issues, field.text, FIELD_MAX_LENGTH, "section.field.text.too_long", "fields[#{index}].text", "Text")
      end
    end

    if accessory = @accessory
      accessory.validate.each { |issue| issues << issue.at("accessory") }
      issues.concat(ChannelResponseUrl.validate(accessory, "accessory.response_url_enabled"))
    end
    length_issue(issues, @block_id, BLOCK_ID_MAX_LENGTH, "section.block_id.too_long", "block_id", "Block ID")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "text", @text if @text
      json.field "fields", @fields if @fields
      json.field "accessory", @accessory if @accessory
      json.field "block_id", @block_id if @block_id
      json.field "expand", @expand unless @expand.nil?
    end
  end

  private def copy_fields(fields : Enumerable(T)) : Array(Text) forall T
    copied = [] of Text
    fields.each { |field| append_field(copied, field) }
    copied
  end

  private def append_field(fields : Array(Text), field : Text) : Nil
    fields << field
  end
end
