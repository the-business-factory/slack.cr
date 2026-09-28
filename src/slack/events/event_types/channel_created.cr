# A channel was created. Requires the `channels:read` scope.
# https://docs.slack.dev/reference/events/channel_created
struct Slack::Events::ChannelCreated < Slack::Event
  getter channel : Slack::EventData::Channel
end
