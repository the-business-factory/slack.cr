struct Slack::Events::Message::MessageChanged < Slack::Event
  include Slack::Events::MessageSubtype

  property hidden : Bool,
    previous_message : Slack::EventData::MessageSubset?,
    message : Slack::EventData::MessageSubset,
    text : String?
end
