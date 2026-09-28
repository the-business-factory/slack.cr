struct Slack::UI::Checked::RichText::Broadcast
  getter range : BroadcastRange
  getter style : Style?

  def initialize(@range : BroadcastRange, @style : Style? = nil)
  end

  def type : String
    "broadcast"
  end

  def validate : Array(ValidationIssue)
    [] of ValidationIssue
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "type", type
      json.field "range", @range.wire_value
      json.field "style", @style if @style
    end
  end
end
