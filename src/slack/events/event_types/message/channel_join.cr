class Slack::Events::Message::ChannelJoin < Slack::Events::MessageSubtype
  property inviter : String, text : String
end
