# A `message` event without a `subtype`: a message that a user or an app posts.
#
# A message with a `subtype` decodes as one of the structs nested in this
# namespace, such as `Message::ChannelTopic`, or as `Message::Unmapped` when
# this library does not map the subtype. These structs inherit `Slack::Event`,
# not `Message`, because a plain message has a stricter field set. Thus
# `is_a?(Message)` means a plain message. Match all subtypes with
# `Slack::Events::MessageSubtype`, and `Message::Unmapped` separately:
#
# ```
# case event = envelope.event
# when Slack::Events::Message           then reply(event.channel, event.text)
# when Slack::Events::MessageSubtype    then log("#{event.subtype} in #{event.channel}")
# when Slack::Events::Message::Unmapped then log("Unmapped #{event.subtype}")
# end
# ```
struct Slack::Events::Message < Slack::Event
  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any?

  property channel : String,
    channel_type : String,
    event_ts : String,
    text : String,
    ts : String,
    user : String

  # `bot_id` and `app_id` are set on messages that an app or bot posts.
  property attachments : Array(Slack::EventData::Attachment)?,
    app_id : String?,
    bot_id : String?,
    client_msg_id : String?,
    parent_user_id : String?,
    team : String?,
    thread_ts : String?

  @[JSON::Field(ignore: true)]
  @decoded_blocks : Array(Slack::Interactions::ReceivedBlock)? = nil

  # Decodes the message blocks. Returns an empty array when the message has none.
  # Raises `Slack::Interactions::TypeMismatch` for a malformed known block.
  # The first call decodes and keeps the result. A copy of this struct made
  # before the first call decodes again.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    @decoded_blocks ||= Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "event.blocks")
  end

  def thread?
    thread_ts.present?
  end

  def public_channel?
    channel_type == "channel"
  end

  def im?
    channel_type == "im"
  end

  def private_channel?
    channel_type == "group"
  end

  def mpim?
    channel_type == "mpim"
  end
end
