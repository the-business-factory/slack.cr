# A received `section` block.
# https://docs.slack.dev/reference/block-kit/blocks/section-block/
struct Slack::Interactions::ReceivedBlocks::Section
  getter block_id : String?
  getter text : ReceivedText?
  getter accessory : ElementSummary?
  getter expand : Bool?
  @fields : Array(ReceivedText)

  def initialize(object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @text = Decoder.text?(object, "text", path)
    @fields = Decoder.texts(object, "fields", path)
    @accessory = Decoder.element?(object, "accessory", path)
    @expand = Decoder.bool?(object, "expand", path)
  end

  def fields : Array(ReceivedText)
    @fields.dup
  end
end
