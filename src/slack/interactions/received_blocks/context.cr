# A text object, or a summary of an image element.
alias Slack::Interactions::ReceivedBlocks::ContextElement = Slack::Interactions::ReceivedText |
                                                            Slack::Interactions::ReceivedBlocks::ElementSummary

# A received `context` block.
# https://docs.slack.dev/reference/block-kit/blocks/context-block/
struct Slack::Interactions::ReceivedBlocks::Context
  getter block_id : String?
  @elements : Array(ContextElement)

  def initialize(object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @elements = Decoder.items(object, "elements", path).map_with_index do |item, index|
      Decoder.context_element(item, "#{path}.elements[#{index}]")
    end
  end

  def elements : Array(ContextElement)
    @elements.dup
  end
end
