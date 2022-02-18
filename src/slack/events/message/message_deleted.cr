class Slack::Events::Message::MessageDeleted < Slack::Events::MessageSubtype
  property hidden : Bool, previous_message : Message
end
