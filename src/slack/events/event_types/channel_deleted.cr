# A channel was deleted.
# https://docs.slack.dev/reference/events/channel_deleted
struct Slack::Events::ChannelDeleted < Slack::Event
  getter channel : String
end
