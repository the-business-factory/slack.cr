# The `assistant_app_thread` object of an assistant thread root message.
# Slack does not document the `artifacts` schema, so it stays raw JSON.
struct Slack::EventData::AssistantAppThread
  include JSON::Serializable

  getter title : String?

  @[JSON::Field(key: "title_blocks", emit_null: false)]
  @title_blocks_raw : JSON::Any?

  @[JSON::Field(emit_null: false)]
  getter artifacts : JSON::Any?

  # Decodes the title blocks. Returns an empty array when there are none.
  # Raises `Slack::Interactions::TypeMismatch` for a malformed known block.
  def title_blocks : Array(Slack::Interactions::ReceivedBlock)
    Slack::Interactions::ReceivedBlocks.decode(@title_blocks_raw, "assistant_app_thread.title_blocks")
  end
end
