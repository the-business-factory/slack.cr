# A received `alert` block. `level` is the level name, such as `warning`.
# https://docs.slack.dev/reference/block-kit/blocks/alert-block
struct Slack::Interactions::ReceivedBlocks::Alert
  getter block_id : String?
  getter text : ReceivedText
  getter level : String?

  def initialize(object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @text = Decoder.text(object, "text", path)
    @level = Decoder.string?(object, "level", path)
  end
end
