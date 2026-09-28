struct Slack::Events::Message::FileShare < Slack::Event
  include Slack::Events::MessageSubtype

  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any?

  property \
    files : Array(JSON::Any),
    text : String?,
    user : String

  # Decodes the message blocks. Returns an empty array when the message has none.
  # Raises `Slack::Interactions::TypeMismatch` for a malformed known block.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "event.blocks")
  end
end
