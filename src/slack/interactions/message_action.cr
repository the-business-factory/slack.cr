struct Slack::Interactions::MessageAction < Slack::Interaction
  @[JSON::Field(emit_null: false)]
  property callback_id : String?

  @[JSON::Field(emit_null: false)]
  property channel : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property message : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property response_url : String?

  @[JSON::Field(emit_null: false)]
  property trigger_id : String?
end
