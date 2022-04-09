abstract struct Slack::Interaction
  include JSON::Serializable

  property type : String

  use_json_discriminator "type", {
    block_actions:   Slack::Interactions::BlockAction,
    view_submission: Slack::Interactions::ViewSubmission,
    view_closed:     Slack::Interactions::ViewClosed,
    shortcut:        Slack::Interactions::Shortcut,
  }
end
