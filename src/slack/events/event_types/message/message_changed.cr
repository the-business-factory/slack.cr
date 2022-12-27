struct Slack::Events::Message::MessageChanged < Slack::Event
  include Slack::Events::MessageSubtype

  property previous_message : Slack::EventData::MessageSubset?,
    message : Slack::EventData::MessageSubset,
    text : String?

  property? hidden = false
end
