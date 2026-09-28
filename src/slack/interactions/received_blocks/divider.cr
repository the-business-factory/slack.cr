# A received `divider` block.
# https://docs.slack.dev/reference/block-kit/blocks/divider-block/
struct Slack::Interactions::ReceivedBlocks::Divider
  getter raw : JSON::Any
  getter block_id : String?

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
  end
end
