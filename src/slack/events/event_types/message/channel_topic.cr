# A user set the channel topic.
# https://docs.slack.dev/reference/events/message/channel_topic
struct Slack::Events::Message::ChannelTopic < Slack::Event
  include Slack::Events::MessageSubtype

  property text : String, topic : String, user : String
end
