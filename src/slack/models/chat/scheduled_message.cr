# One message that is scheduled to post, from `chat.scheduledMessages.list`.
struct Slack::Models::Chat::ScheduledMessage < Slack::Model
  @[JSON::Field(converter: Slack::Models::Chat::ScheduledMessageIdConverter)]
  getter id : String
  getter channel_id : String
  @[JSON::Field(converter: Slack::Models::Chat::UnixTimeConverter)]
  getter post_at : Time
  @[JSON::Field(converter: Slack::Models::Chat::UnixTimeConverter)]
  getter date_created : Time
  getter text : String?
end
