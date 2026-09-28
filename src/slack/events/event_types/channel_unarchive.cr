# A user unarchived a channel.
# https://docs.slack.dev/reference/events/channel_unarchive
struct Slack::Events::ChannelUnarchive < Slack::Event
  getter channel : String
  getter user : String
end
