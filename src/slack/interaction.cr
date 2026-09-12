abstract struct Slack::Interaction
  include JSON::Serializable

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

  use_json_discriminator "type", {
    block_actions:   Slack::Interactions::BlockAction,
    message_action:  Slack::Interactions::MessageAction,
    view_submission: Slack::Interactions::ViewSubmission,
    view_closed:     Slack::Interactions::ViewClosed,
    shortcut:        Slack::Interactions::Shortcut,
  }
end
