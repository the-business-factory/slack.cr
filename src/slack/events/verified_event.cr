struct Slack::VerifiedEvent
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer \
    api_app_id : String,
    authorizations : Array(Slack::Events::Authorization) = [] of Slack::Events::Authorization,
    event : Slack::Event,
    event_context : String? = nil,
    event_id : String,
    team_id : String? = nil,
    token : String,
    type : String

  @[JSON::Field(converter: Time::EpochConverter)]
  properties_with_initializer event_time : Time
end
