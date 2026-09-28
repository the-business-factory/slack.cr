# A message that a Web API method returns, with the common typed fields.
# `blocks` decodes the received blocks when called. Attachments and metadata
# stay raw JSON.
struct Slack::Models::Message < Slack::Model
  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any?

  getter ts : String
  getter type : String
  getter subtype : String?
  getter text : String?
  getter user : String?
  getter bot_id : String?
  getter thread_ts : String?
  getter attachments : JSON::Any?
  getter metadata : JSON::Any?

  # Returns an empty array when the message has no blocks. Raises
  # `Slack::Interactions::TypeMismatch` for a malformed known block.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "message.blocks")
  end
end
