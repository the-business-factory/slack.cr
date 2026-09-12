struct Slack::Interactions::ViewClosed < Slack::Interaction
  @[JSON::Field(emit_null: false)]
  property view : Slack::Interactions::View?
end
