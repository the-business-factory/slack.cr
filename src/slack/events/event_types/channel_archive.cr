# A user archived a channel.
# https://docs.slack.dev/reference/events/channel_archive
struct Slack::Events::ChannelArchive < Slack::Event
  getter channel : String
  getter user : String
end
