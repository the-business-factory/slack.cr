abstract struct Slack::Interaction
  include JSON::Serializable

  property type : String

  use_json_discriminator "type", {
    block_actions: Slack::Interactions::BlockAction,
  }
end
