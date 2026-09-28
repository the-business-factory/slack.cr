# A `message` event. Slack omits `channel`, `user`, `team`, `text`, and
# `channel_type` in some messages, such as a message with an unmapped subtype.
struct Slack::Events::Message < Slack::Event
  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any?

  # `bot_id` is set on messages that an app or bot posts.
  property attachments : Array(Slack::EventData::Attachment)?,
    bot_id : String?,
    channel : String?,
    channel_type : String?,
    client_msg_id : String?,
    parent_user_id : String?,
    team : String?,
    text : String?,
    thread_ts : String?,
    ts : String?,
    user : String?

  # Nil for an ordinary message. A subtype that this library does not map also
  # decodes as `Message`; this getter gives its name.
  @[JSON::Field(emit_null: false)]
  getter subtype : String?

  # Decodes the message blocks. Returns an empty array when the message has none.
  # Raises `Slack::Interactions::TypeMismatch` for a malformed known block.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "event.blocks")
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
