# Retains an interaction payload whose `type` this library does not map.
#
# No listener matches it, and the app acknowledges it with an empty response.
# `raw` holds the complete payload, and `to_json` emits it unchanged. `raw`
# can hold credentials, such as a `response_url`, so do not log it.
#
# The shared `Slack::Interaction` getters read from `raw`. A string or bool
# value of another JSON type reads as nil. A `team`, `enterprise`, or `user`
# object decodes as for a mapped type and raises `JSON::SerializableError`
# when its shape is not valid, because authorization reads these fields.
struct Slack::Interactions::Unknown < Slack::Interaction
  getter raw : JSON::Any

  def self.new(pull : JSON::PullParser) : self
    location = pull.location
    raw = JSON::Any.new(pull)
    type = Slack::Discriminated.value(raw, "type", "Slack::Interactions::Unknown", location) ||
           raise JSON::SerializableError.new("Missing string JSON discriminator field 'type'", "Slack::Interactions::Unknown", nil, *location, nil)
    new(type, raw)
  end

  def initialize(@type : String, @raw : JSON::Any)
    @api_app_id = @raw["api_app_id"]?.try(&.as_s?)
    @is_enterprise_install = @raw["is_enterprise_install"]?.try(&.as_bool?)
    @team = raw_object("team", Slack::Interactions::Team)
    @enterprise = raw_object("enterprise", Slack::Interactions::Enterprise)
    @user = raw_object("user", Slack::Interactions::User)
  end

  def to_json(json : JSON::Builder) : Nil
    @raw.to_json(json)
  end

  private def raw_object(key : String, type : T.class) : T? forall T
    value = @raw[key]?
    return if value.nil? || value.raw.nil?
    type.from_json(value.to_json)
  end
end
