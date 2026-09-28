struct Slack::UI::Checked::RichText::Channel
  include NodeValidation

  getter channel_id : String
  getter style : Style?

  def initialize(@channel_id : String, @style : Style? = nil)
    validate!
  end

  def type : String
    "channel"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @channel_id, "channel.channel_id.empty", "channel_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "channel_id", @channel_id
      json.field "style", @style if @style
    end
  end
end
