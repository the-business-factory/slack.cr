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

  @[JSON::Field(emit_null: false)]
  properties_with_initializer context_enterprise_id : String? = nil

  @[JSON::Field(emit_null: false)]
  properties_with_initializer context_team_id : String? = nil

  @[JSON::Field(emit_null: false)]
  properties_with_initializer is_ext_shared_channel : Bool? = nil

  @[JSON::Field(converter: Time::EpochConverter)]
  properties_with_initializer event_time : Time
end
