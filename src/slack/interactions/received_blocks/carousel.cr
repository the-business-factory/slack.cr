# A received `carousel` block. Slack sends `card` blocks as elements; they
# decode like top-level blocks.
# https://docs.slack.dev/reference/block-kit/blocks/carousel-block
struct Slack::Interactions::ReceivedBlocks::Carousel
  getter raw : JSON::Any
  getter block_id : String?
  @elements : Array(ReceivedBlock)

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @elements = Decoder.blocks(object, "elements", path)
  end

  def elements : Array(ReceivedBlock)
    @elements.dup
  end
end
