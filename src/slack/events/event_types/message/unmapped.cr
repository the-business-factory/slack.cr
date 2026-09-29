# Retains a `message` event whose `subtype` this library does not map.
#
# `raw` holds the complete event object, and `to_json` emits it unchanged.
# Read the fields of the subtype from `raw`. The shared `Slack::Event` getters
# read string values from `raw`; a value of another JSON type reads as nil.
struct Slack::Events::Message::Unmapped < Slack::Event
  getter subtype : String
  getter raw : JSON::Any

  def self.new(pull : JSON::PullParser) : self
    location = pull.location
    raw = JSON::Any.new(pull)
    subtype = Slack::Events::MessageFactory.subtype(raw, location) ||
              raise JSON::SerializableError.new("Missing string message field 'subtype'", "Slack::Events::Message::Unmapped", nil, *location, nil)
    new(subtype, raw)
  end

  def initialize(@subtype : String, @raw : JSON::Any)
    @type = raw_string("type") || "message"
    @team_id = raw_string("team_id")
    @source_team_id = raw_string("source_team")
    @user_team_id = raw_string("user_team")
  end

  def to_json(json : JSON::Builder) : Nil
    @raw.to_json(json)
  end

  private def raw_string(key : String) : String?
    @raw[key]?.try(&.as_s?)
  end
end
