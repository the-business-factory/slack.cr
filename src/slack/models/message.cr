# A message that a Web API method returns, with the common typed fields.
# `blocks` decodes the received blocks when called. Attachments and metadata
# stay raw JSON. `reply_count` is present on a thread parent in
# `conversations.history` and `conversations.replies`. `reactions` is present
# on messages that `reactions.get`, `reactions.list`, and channel history return.
# `type` defaults to `message`: `reactions.list` omits it on nested bot messages.
struct Slack::Models::Message < Slack::Model
  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any?

  getter ts : String
  getter type : String = "message"
  getter subtype : String?
  getter text : String?
  getter user : String?
  getter bot_id : String?
  getter thread_ts : String?
  getter reply_count : Int32?
  getter files : Array(Slack::Models::File)?
  getter reactions : Array(Slack::Models::Reaction)?
  getter attachments : JSON::Any?
  getter metadata : JSON::Any?

  # Returns an empty array when the message has no blocks. Raises
  # `Slack::Interactions::TypeMismatch` for a malformed known block.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "message.blocks")
  end
end
