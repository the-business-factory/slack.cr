struct Slack::Events::Message::MessageDeleted < Slack::Event
  include Slack::Events::MessageSubtype

  property previous_message : Slack::EventData::MessageSubset?

  property? hidden = false
end
