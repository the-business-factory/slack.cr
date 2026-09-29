struct Slack::UI::Blocks::Divider
  include Slack::UI::ValueValidation

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
    length_issue(issues, @block_id, BLOCK_ID_MAX_LENGTH, "divider.block_id.too_long", "block_id", "Block ID")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
    end
  end
end
