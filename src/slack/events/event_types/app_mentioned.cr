# A message that mentions the app. To reply in the mention's thread, send
# `thread_ts || ts` as the reply's `thread_ts`.
# https://docs.slack.dev/reference/events/app_mention
struct Slack::Events::AppMentioned < Slack::Event
  # The canvas section that mentions the app, in a `document_mention` subtype.
  # https://docs.slack.dev/reference/events/message/document_mention
  struct DocumentMention
    include JSON::Serializable

    getter file_id : String
    getter section_id : String
    getter mentioning_user_ids : Array(String) = [] of String
  end

  @[JSON::Field(key: "blocks", emit_null: false)]
  @blocks_raw : JSON::Any?

  property channel : String, user : String

  getter text : String
  getter ts : String
  getter event_ts : String

  # The parent message timestamp when the mention is a thread reply; nil at top level.
  getter thread_ts : String?

  # The workspace of the mentioning user. The reference example omits it.
  getter team : String?

  # `document_mention` when the app is mentioned in the body of a canvas; nil
  # for a mention in a message.
  getter subtype : String?

  getter document_mention : DocumentMention?

  @[JSON::Field(ignore: true)]
  @decoded_blocks : Array(Slack::Interactions::ReceivedBlock)? = nil

  # Decodes the message blocks. Returns an empty array when the mention has none.
  # Raises `Slack::Interactions::TypeMismatch` for a malformed known block.
  # The first call decodes and keeps the result. A copy of this struct made
  # before the first call decodes again.
  def blocks : Array(Slack::Interactions::ReceivedBlock)
    @decoded_blocks ||= Slack::Interactions::ReceivedBlocks.decode(@blocks_raw, "event.blocks")
  end
end
