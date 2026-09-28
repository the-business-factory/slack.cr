# One item that a user views, such as a channel, in an `app_context_changed`
# event.
struct Slack::EventData::ContextEntity
  include JSON::Serializable

  # A Slack type name, such as `slack#/types/channel_id`.
  getter type : String
  getter value : String
  getter team_id : String?
end
