struct Slack::EventData::MessageSubset
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer \
    attachments : Array(Slack::EventData::Attachment)? = [] of Slack::EventData::Attachment,
    client_msg_id : String? = nil,
    team : String? = nil,
    text : String,
    ts : String

  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any? = nil

  # Decodes the message blocks. Returns an empty array when the message has none.
  # Raises `Slack::Interactions::TypeMismatch` for a malformed known block.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "message.blocks")
  end
end
