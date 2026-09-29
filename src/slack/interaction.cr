# An interaction payload, for example a button click or a view submission.
#
# Decoding selects a typed struct by the `type` field. A `type` that this
# library does not map decodes as `Slack::Interactions::Unknown`; no listener
# matches it, and the app acknowledges it.
abstract struct Slack::Interaction
  include JSON::Serializable
  include Slack::Discriminated

  property type : String

  @[JSON::Field(emit_null: false)]
  property api_app_id : String?

  @[JSON::Field(emit_null: false)]
  property team : Slack::Interactions::Team?

  @[JSON::Field(emit_null: false)]
  property enterprise : Slack::Interactions::Enterprise?

  @[JSON::Field(emit_null: false)]
  property user : Slack::Interactions::User?

  @[JSON::Field(emit_null: false)]
  property is_enterprise_install : Bool?

  discriminated_by "type", {
    block_actions:    Slack::Interactions::BlockAction,
    block_suggestion: Slack::Interactions::BlockSuggestion,
    message_action:   Slack::Interactions::MessageAction,
    view_submission:  Slack::Interactions::ViewSubmission,
    view_closed:      Slack::Interactions::ViewClosed,
    shortcut:         Slack::Interactions::Shortcut,
  }, fallback: Slack::Interactions::Unknown
end
