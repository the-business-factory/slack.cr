struct Slack::UI::Blocks::Divider
  BLOCK_ID_MAX_LENGTH = 255

  getter block_id : String?

  def initialize(@block_id : String? = nil)
    validate!
  end

  def type : String
    "divider"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @block_id.try(&.size.>(BLOCK_ID_MAX_LENGTH))
      issues << Slack::UI::ValidationIssue.new(
        code: "divider.block_id.too_long",
        path: "block_id",
        message: "Block ID cannot be longer than #{BLOCK_ID_MAX_LENGTH} characters."
      )
    end
    issues
  end

  def validate! : Nil
    issues = validate
    raise Slack::UI::ValidationError.new(issues) unless issues.empty?
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
    end
  end
end
