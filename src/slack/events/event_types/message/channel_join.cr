struct Slack::Events::Message::ChannelJoin < Slack::Event
  include Slack::Events::MessageSubtype

  property inviter : String?, text : String
end
