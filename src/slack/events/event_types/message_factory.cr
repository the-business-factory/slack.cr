# Selects the `message` event struct by `subtype`.
#
# A message without a subtype, or with a subtype that this library does not
# map, decodes as the base `Slack::Events::Message`. Its `subtype` getter gives
# the unmapped value.
struct Slack::Events::MessageFactory
  # Keep the explicit type dispatch together rather than split the discriminator mapping.
  # ameba:disable Metrics/CyclomaticComplexity
  def self.new(pull : JSON::PullParser) : Slack::Event
    location = pull.location
    raw = JSON::Any.new(pull)
    json = raw.to_json

    case subtype(raw, location)
    when "bot_add"          then Slack::Events::Message::BotAdd.from_json(json)
    when "bot_message"      then Slack::Events::Message::BotMessage.from_json(json)
    when "channel_join"     then Slack::Events::Message::ChannelJoin.from_json(json)
    when "channel_leave"    then Slack::Events::Message::ChannelLeave.from_json(json)
    when "channel_name"     then Slack::Events::Message::ChannelName.from_json(json)
    when "channel_purpose"  then Slack::Events::Message::ChannelPurpose.from_json(json)
    when "channel_topic"    then Slack::Events::Message::ChannelTopic.from_json(json)
    when "file_share"       then Slack::Events::Message::FileShare.from_json(json)
    when "me_message"       then Slack::Events::Message::MeMessage.from_json(json)
    when "message_changed"  then Slack::Events::Message::MessageChanged.from_json(json)
    when "message_deleted"  then Slack::Events::Message::MessageDeleted.from_json(json)
    when "message_replied"  then Slack::Events::Message::MessageReplied.from_json(json)
    when "pinned_item"      then Slack::Events::Message::PinnedItem.from_json(json)
    when "thread_broadcast" then Slack::Events::Message::ThreadBroadcast.from_json(json)
    when "unpinned_item"    then Slack::Events::Message::UnpinnedItem.from_json(json)
    else                         Slack::Events::Message.from_json(json)
    end
  end

  private def self.subtype(raw : JSON::Any, location : Tuple(Int32, Int32)) : String?
    object = raw.as_h? || raise JSON::SerializableError.new("Expected a JSON object for a message event", "Slack::Events::MessageFactory", nil, *location, nil)
    value = object["subtype"]?
    return if value.nil? || value.raw.nil?
    value.as_s? || raise JSON::SerializableError.new("Message field 'subtype' must be a string", "Slack::Events::MessageFactory", nil, *location, nil)
  end
end
