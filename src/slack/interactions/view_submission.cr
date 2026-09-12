struct Slack::Interactions::ViewSubmission < Slack::Interaction
  @[JSON::Field(emit_null: false)]
  property response_urls : JSON::Any?

  @[JSON::Field(emit_null: false)]
  property view : Slack::Interactions::View?
end
