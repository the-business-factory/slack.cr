# A received `context_actions` block with feedback and icon buttons.
# https://docs.slack.dev/reference/block-kit/blocks/context-actions-block/
struct Slack::Interactions::ReceivedBlocks::ContextActions
  getter raw : JSON::Any
  getter block_id : String?
  @elements : Array(ElementSummary)

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @elements = Decoder.elements(object, "elements", path)
  end

  def elements : Array(ElementSummary)
    @elements.dup
  end
end
