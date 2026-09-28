# A received `header` block.
# https://docs.slack.dev/reference/block-kit/blocks/header-block/
struct Slack::Interactions::ReceivedBlocks::Header
  getter raw : JSON::Any
  getter block_id : String?
  getter text : ReceivedText
  getter level : Int32?

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @text = Decoder.text(object, "text", path)
    @level = Decoder.int32?(object, "level", path)
  end
end
