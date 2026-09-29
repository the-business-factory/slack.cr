struct Slack::Events::Message::FileShare < Slack::Event
  include Slack::Events::MessageSubtype

  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any?

  property \
    files : Array(JSON::Any),
    text : String?,
    user : String

  @[JSON::Field(ignore: true)]
  @decoded_blocks : Array(Slack::Interactions::ReceivedBlock)? = nil

  # Decodes the message blocks. Returns an empty array when the message has none.
  # Raises `Slack::Interactions::TypeMismatch` for a malformed known block.
  # The first call decodes and keeps the result. A copy of this struct made
  # before the first call decodes again.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    @decoded_blocks ||= Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "event.blocks")
  end
end
