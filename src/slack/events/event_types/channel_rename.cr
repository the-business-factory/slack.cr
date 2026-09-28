# A channel was renamed. `channel.name` is the new name.
# https://docs.slack.dev/reference/events/channel_rename
struct Slack::Events::ChannelRename < Slack::Event
  getter channel : Slack::EventData::Channel
end
