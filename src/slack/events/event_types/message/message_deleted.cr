struct Slack::Events::Message::MessageDeleted < Slack::Event
  include Slack::Events::MessageSubtype

  property hidden : Bool, previous_message : Slack::EventData::MessageSubset?
end
