class Slack::Events::Message::MessageDeleted < Slack::Events::MessageSubtype
  property hidden : Bool, previous_message : Slack::EventData::MessageSubset
end
