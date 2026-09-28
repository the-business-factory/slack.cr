# A user set the channel purpose.
# https://docs.slack.dev/reference/events/message/channel_purpose
struct Slack::Events::Message::ChannelPurpose < Slack::Event
  include Slack::Events::MessageSubtype

  property purpose : String, text : String, user : String
end
