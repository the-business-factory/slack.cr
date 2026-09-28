# A short status message. Slack shows alert blocks in modals only, so only
# the modal unions contain it; Message and Home reject it at compile time.
#
# A `nil` level omits the field, and Slack then shows the default level.
struct Slack::UI::Checked::Blocks::Alert
  include Slack::UI::Checked::ValueValidation

  TEXT_MAX_LENGTH = 200

  getter text : Slack::UI::Checked::CompositionObjects::Text
  getter level : Slack::UI::Checked::Blocks::AlertLevel?
  getter block_id : String?

  def initialize(
    @text : Slack::UI::Checked::CompositionObjects::Text,
    @level : Slack::UI::Checked::Blocks::AlertLevel? = nil,
    @block_id : String? = nil,
  )
    validate!
  end

  def type : String
    "alert"
  end

  def validate : Array(ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    length_issue(issues, @text.text, TEXT_MAX_LENGTH, "alert.text.too_long", "text.text")
    length_issue(issues, @block_id, 255, "alert.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
      json.field "text", @text
      if level = @level
        json.field "level", level.wire_value
      end
    end
  end
end
