class Slack::Events::Message::MessageChanged < Slack::Events::MessageSubtype
  property channel : String,
    channel_type : String,
    hidden : Bool,
    previous_message : Message,
    message : Message,
    text : String?
end
