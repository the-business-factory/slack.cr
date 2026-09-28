# A received `actions` block. Read the selected values from the action payload
# or `state.values`; the elements here are summaries.
# https://docs.slack.dev/reference/block-kit/blocks/actions-block/
struct Slack::Interactions::ReceivedBlocks::Actions
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
