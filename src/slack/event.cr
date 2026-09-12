abstract struct Slack::Event
  include JSON::Serializable
  include Slack::JSONRecords

  property type : String

  @[JSON::Field(emit_null: false)]
  property team_id : String?

  @[JSON::Field(key: "source_team", emit_null: false)]
  property source_team_id : String?

  @[JSON::Field(key: "user_team", emit_null: false)]
  property user_team_id : String?

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
