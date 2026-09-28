# Retains an inner event whose `type` this library does not map.
#
# `raw` holds the complete event object, and `to_json` emits it unchanged.
# `raw` can hold credentials, such as a workflow `bot_access_token`, so do not
# log it.
# The shared `Slack::Event` getters read string values from `raw`; a value of
# another JSON type reads as nil because the event schema is not known.
struct Slack::Events::Unknown < Slack::Event
  getter raw : JSON::Any

  def self.new(pull : JSON::PullParser) : self
    location = pull.location
    raw = JSON::Any.new(pull)
    new(event_type(raw, location), raw)
  end

  def initialize(@type : String, @raw : JSON::Any)
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
