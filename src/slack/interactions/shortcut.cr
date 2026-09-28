# A global shortcut.
# https://docs.slack.dev/reference/interaction-payloads/shortcuts-interaction-payload/
struct Slack::Interactions::Shortcut < Slack::Interaction
  @[JSON::Field(emit_null: false)]
  property callback_id : String?

  @[JSON::Field(emit_null: false)]
  property trigger_id : String?

  @[JSON::Field(emit_null: false)]
  getter channel : Channel?
end
