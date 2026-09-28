# A member left the channel. `Slack::Events::MemberLeftChannel` is the
# dedicated event for this.
# https://docs.slack.dev/reference/events/message/channel_leave
struct Slack::Events::Message::ChannelLeave < Slack::Event
  include Slack::Events::MessageSubtype

  property text : String, user : String
end
