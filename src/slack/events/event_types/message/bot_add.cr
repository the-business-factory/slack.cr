struct Slack::Events::Message::BotAdd < Slack::Event
  include Slack::Events::MessageSubtype

  property bot_id : String,
    bot_link : String,
    text : String,
    user : String
end
