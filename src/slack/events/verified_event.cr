class Slack::VerifiedEvent
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer \
    api_app_id : String,
    authorizations : Array(JSON::Any) = [] of JSON::Any,
    event : Slack::Event,
    event_context : String?,
    event_id : String,
    team_id : String,
    token : String,
    type : String

  @[JSON::Field(converter: Time::EpochConverter)]
  properties_with_initializer event_time : Time

  def after_initialize
    @event.team_id = team_id
  end
end
