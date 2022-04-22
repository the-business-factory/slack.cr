class Slack::Events::MessageFactory
  include Slack::OptionalDiscriminator

  use_optional_discriminator_on "subtype",
    Slack::Events::Message,
    {
      bot_add:         Slack::Events::Message::BotAdd,
      channel_join:    Slack::Events::Message::ChannelJoin,
      file_share:      Slack::Events::Message::FileShare,
      message_changed: Slack::Events::Message::MessageChanged,
      message_deleted: Slack::Events::Message::MessageDeleted,
    }
end
