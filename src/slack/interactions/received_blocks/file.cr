# A received remote `file` block.
# https://docs.slack.dev/reference/block-kit/blocks/file-block/
struct Slack::Interactions::ReceivedBlocks::File
  getter block_id : String?
  getter external_id : String
  getter source : String

  def initialize(object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @external_id = Decoder.string(object, "external_id", path)
    @source = Decoder.string(object, "source", path)
  end
end
