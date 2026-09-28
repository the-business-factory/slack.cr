# A message shortcut.
# https://docs.slack.dev/reference/interaction-payloads/shortcuts-interaction-payload/
struct Slack::Interactions::MessageAction < Slack::Interaction
  @[JSON::Field(emit_null: false)]
  property callback_id : String?

  @[JSON::Field(emit_null: false)]
  getter channel : Channel?

  @[JSON::Field(emit_null: false)]
  getter message_ts : String?

  # The source message, with typed received blocks.
  @[JSON::Field(emit_null: false)]
  getter message : ReceivedMessage?

  @[JSON::Field(emit_null: false)]
  property response_url : String?

  @[JSON::Field(emit_null: false)]
  property trigger_id : String?
end
