# https://api.slack.com/reference/interaction-payloads/block-actions
struct Slack::Interactions::BlockAction < Slack::Interaction
  property actions : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property channel : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property container : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property state : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property token : String?

  @[JSON::Field(emit_null: false)]
  property trigger_id : String?

  @[JSON::Field(emit_null: false)]
  property view : Slack::Interactions::View?
end
