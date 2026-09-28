# A user renamed the channel. `name` is the new name.
# https://docs.slack.dev/reference/events/message/channel_name
struct Slack::Events::Message::ChannelName < Slack::Event
  include Slack::Events::MessageSubtype

  property name : String, old_name : String, text : String, user : String
end
