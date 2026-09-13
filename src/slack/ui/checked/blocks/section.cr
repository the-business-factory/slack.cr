struct Slack::UI::Checked::Blocks::Section
  alias Text = Slack::UI::Checked::CompositionObjects::Text
  alias Accessory = Slack::UI::Checked::BlockElements::Button

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
    Slack::UI::Checked::DeclaredTypes.text(T)
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
    Slack::UI::Checked::DeclaredTypes.text(T)
    @fields = copy_fields(fields)
    validate!
  end

  def type : String
    "section"
  end

  def fields : Array(Text)?
    @fields.try(&.dup)
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @text.nil? && @fields.nil?
      issues << Slack::UI::Checked::ValidationIssue.new(
        code: "section.content.missing",
        path: "section",
        message: "Text or fields must be present."
      )
    end

    if text = @text
      text.validate.each { |issue| issues << issue.at("text") }
      append_text_length_issue(issues, text.text, TEXT_MAX_LENGTH, "section.text.too_long", "text.text")
    end

    if fields = @fields
      if fields.empty?
        issues << Slack::UI::Checked::ValidationIssue.new(
          code: "section.fields.empty",
          path: "fields",
          message: "Fields must contain at least one text object."
        )
      elsif fields.size > FIELDS_MAX_SIZE
        issues << Slack::UI::Checked::ValidationIssue.new(
          code: "section.fields.too_many",
          path: "fields",
          message: "Fields cannot contain more than #{FIELDS_MAX_SIZE} text objects."
        )
      end

      fields.each_with_index do |field, index|
        field.validate.each { |issue| issues << issue.at("fields[#{index}]") }
        append_text_length_issue(
          issues,
          field.text,
          FIELD_MAX_LENGTH,
          "section.field.text.too_long",
          "fields[#{index}].text"
        )
      end
    end

    if accessory = @accessory
      accessory.validate.each { |issue| issues << issue.at("accessory") }
    end
    append_block_id_issue(issues)
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

  private def append_field(fields : Array(Text), field : Slack::UI::Checked::CompositionObjects::PlainText) : Nil
    fields << field
  end

  private def append_field(fields : Array(Text), field : Slack::UI::Checked::CompositionObjects::Mrkdwn) : Nil
    fields << field
  end

  private def append_text_length_issue(
    issues : Array(Slack::UI::Checked::ValidationIssue),
    value : String,
    maximum : Int32,
    code : String,
    path : String,
  ) : Nil
    return unless value.size > maximum

    issues << Slack::UI::Checked::ValidationIssue.new(
      code: code,
      path: path,
      message: "Text cannot be longer than #{maximum} characters."
    )
  end

  private def append_block_id_issue(issues : Array(Slack::UI::Checked::ValidationIssue)) : Nil
    return unless @block_id.try(&.size.>(BLOCK_ID_MAX_LENGTH))

    issues << Slack::UI::Checked::ValidationIssue.new(
      code: "section.block_id.too_long",
      path: "block_id",
      message: "Block ID cannot be longer than #{BLOCK_ID_MAX_LENGTH} characters."
    )
  end
end
