struct Slack::EventData::MessageSubset
  include JSON::Serializable
  include Slack::InitializerMacros

  properties_with_initializer \
    attachments : Array(Slack::EventData::Attachment)? = [] of Slack::EventData::Attachment,
    client_msg_id : String? = nil,
    team : String? = nil,
    text : String,
    ts : String

  # The subtype of this message, such as `assistant_app_thread`. Nil for an
  # ordinary message.
  @[JSON::Field(emit_null: false)]
  getter subtype : String? = nil

  # Slack sends it when `subtype` is `assistant_app_thread`.
  @[JSON::Field(emit_null: false)]
  getter assistant_app_thread : Slack::EventData::AssistantAppThread? = nil

  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any? = nil

  @[JSON::Field(ignore: true)]
  @decoded_blocks : Array(Slack::Interactions::ReceivedBlock)? = nil

  # Decodes the message blocks. Returns an empty array when the message has none.
  # Raises `Slack::Interactions::TypeMismatch` for a malformed known block.
  # The first call decodes and keeps the result. A copy of this struct made
  # before the first call decodes again.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    @decoded_blocks ||= Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "message.blocks")
  end
end
