# The channel object in a `channel_created` or `channel_rename` event.
struct Slack::EventData::Channel
  include JSON::Serializable

  getter id : String
  getter name : String

  @[JSON::Field(converter: Slack::EpochConverter)]
  getter created : Time

  # The user who created the channel. `channel_rename` does not send it.
  getter creator : String?
end
