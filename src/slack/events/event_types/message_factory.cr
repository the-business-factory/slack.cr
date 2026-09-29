# Selects the `message` event struct by `subtype`.
#
# A message without a subtype decodes as `Slack::Events::Message`. A subtype
# that this library does not map decodes as `Slack::Events::Message::Unmapped`.
struct Slack::Events::MessageFactory
  include Slack::Discriminated

  discriminated_by "subtype", {
    assistant_app_thread: Slack::Events::Message::AssistantAppThread,
    bot_add:              Slack::Events::Message::BotAdd,
    bot_message:          Slack::Events::Message::BotMessage,
    channel_join:         Slack::Events::Message::ChannelJoin,
    channel_leave:        Slack::Events::Message::ChannelLeave,
    channel_name:         Slack::Events::Message::ChannelName,
    channel_purpose:      Slack::Events::Message::ChannelPurpose,
    channel_topic:        Slack::Events::Message::ChannelTopic,
    file_share:           Slack::Events::Message::FileShare,
    me_message:           Slack::Events::Message::MeMessage,
    message_changed:      Slack::Events::Message::MessageChanged,
    message_deleted:      Slack::Events::Message::MessageDeleted,
    message_replied:      Slack::Events::Message::MessageReplied,
    pinned_item:          Slack::Events::Message::PinnedItem,
    thread_broadcast:     Slack::Events::Message::ThreadBroadcast,
    unpinned_item:        Slack::Events::Message::UnpinnedItem,
  }, fallback: Slack::Events::Message::Unmapped, default: Slack::Events::Message
end
