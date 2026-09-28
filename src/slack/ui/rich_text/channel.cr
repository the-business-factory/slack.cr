struct Slack::UI::RichText::Channel
  include NodeValidation

  getter channel_id : String
  getter style : Style?
  getter tab_id : String?

  def initialize(@channel_id : String, @style : Style? = nil, @tab_id : String? = nil)
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
      json.field "tab_id", @tab_id if @tab_id
      json.field "style", @style if @style
    end
  end
end
