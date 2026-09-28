# A received `image` block. `slack_file` stays raw JSON.
# https://docs.slack.dev/reference/block-kit/blocks/image-block/
struct Slack::Interactions::ReceivedBlocks::Image
  getter raw : JSON::Any
  getter block_id : String?
  getter alt_text : String
  getter image_url : String?
  getter slack_file : JSON::Any?
  getter title : ReceivedText?

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @alt_text = Decoder.string(object, "alt_text", path)
    @image_url = Decoder.string?(object, "image_url", path)
    @slack_file = Decoder.raw?(object, "slack_file")
    @title = Decoder.text?(object, "title", path)
  end
end
