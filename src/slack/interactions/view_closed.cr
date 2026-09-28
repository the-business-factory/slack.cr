# https://docs.slack.dev/reference/interaction-payloads/view-interactions-payload/
struct Slack::Interactions::ViewClosed < Slack::Interaction
  @[JSON::Field(emit_null: false)]
  property view : Slack::Interactions::View?

  # True when the user closed the whole view stack.
  @[JSON::Field(emit_null: false)]
  getter is_cleared : Bool?
end
