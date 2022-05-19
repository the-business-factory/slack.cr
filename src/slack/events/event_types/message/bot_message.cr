struct Slack::Events::Message::BotMessage < Slack::Event
  include Slack::Events::MessageSubtype

  property app_id : String?,
    bot_id : String,
    text : String,
    username : String?
end
