# An inner event from an Events API `event_callback` envelope.
#
# Decoding selects a typed struct by the `type` field. A `type` that this
# library does not map decodes as `Slack::Events::Unknown`, so a new Slack
# event subscription does not break delivery. Match `Unknown` explicitly to
# handle those events.
abstract struct Slack::Event
  include JSON::Serializable
  include Slack::JSONRecords

  property type : String

  @[JSON::Field(emit_null: false)]
  property team_id : String?

  @[JSON::Field(key: "source_team", emit_null: false)]
  property source_team_id : String?

  @[JSON::Field(key: "user_team", emit_null: false)]
  property user_team_id : String?

  def self.new(pull : JSON::PullParser) : Slack::Event
    location = pull.location
    raw = JSON::Any.new(pull)
    type = event_type(raw, location)
    json = raw.to_json

    case type
    when "app_home_opened"   then Slack::Events::AppHomeOpened.from_json(json)
    when "app_mention"       then Slack::Events::AppMentioned.from_json(json)
    when "app_uninstalled"   then Slack::Events::AppUninstalled.from_json(json)
    when "function_executed" then Slack::Events::FunctionExecuted.from_json(json)
    when "message"           then Slack::Events::MessageFactory.from_json(json)
    when "reaction_added"    then Slack::Events::ReactionAdded.from_json(json)
    when "reaction_removed"  then Slack::Events::ReactionRemoved.from_json(json)
    when "tokens_revoked"    then Slack::Events::TokensRevoked.from_json(json)
    else                          Slack::Events::Unknown.new(type, raw)
    end
  end

  private def self.event_type(raw : JSON::Any, location : Tuple(Int32, Int32)) : String
    object = raw.as_h? || raise JSON::SerializableError.new("Expected a JSON object for an event", "Slack::Event", nil, *location, nil)
    object["type"]?.try(&.as_s?) ||
      raise JSON::SerializableError.new("Missing string JSON discriminator field 'type'", "Slack::Event", nil, *location, nil)
  end
end
