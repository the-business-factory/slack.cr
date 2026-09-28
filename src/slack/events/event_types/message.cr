struct Slack::Events::Message < Slack::Event
  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any?

  property attachments : Array(Slack::EventData::Attachment)?,
    channel : String,
    channel_type : String,
    client_msg_id : String?,
    parent_user_id : String?,
    team : String,
    text : String,
    thread_ts : String?,
    ts : String?,
    user : String

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
end
