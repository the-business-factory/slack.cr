class Slack::Events::Message::BotAdd < Slack::Events::MessageSubtype
  property bot_id : String,
    bot_link : String,
    text : String,
    user : String
end
