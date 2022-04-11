abstract class Slack::Event
  include JSON::Serializable

  property type : String

  use_json_discriminator "type", {
    app_home_opened:  Slack::Events::AppHomeOpened,
    app_mention:      Slack::Events::AppMentioned,
    app_uninstalled:  Slack::Events::AppUninstalled,
    message:          Slack::Events::MessageFactory,
    reaction_added:   Slack::Events::ReactionAdded,
    reaction_removed: Slack::Events::ReactionRemoved,
    tokens_revoked:   Slack::Events::TokensRevoked,
  }
end
