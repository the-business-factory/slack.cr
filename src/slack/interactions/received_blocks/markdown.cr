# A received `markdown` block.
# https://docs.slack.dev/reference/block-kit/blocks/markdown-block/
struct Slack::Interactions::ReceivedBlocks::Markdown
  getter raw : JSON::Any
  getter block_id : String?
  getter text : String

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @text = Decoder.string(object, "text", path)
  end
end
