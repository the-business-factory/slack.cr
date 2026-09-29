# A received `input` block. Read the entered value from `state.values`; the
# element here is a summary.
# https://docs.slack.dev/reference/block-kit/blocks/input-block/
struct Slack::Interactions::ReceivedBlocks::Input
  getter block_id : String?
  getter label : ReceivedText
  getter element : ElementSummary
  getter hint : ReceivedText?
  getter optional : Bool?
  getter dispatch_action : Bool?

  def initialize(object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @label = Decoder.text(object, "label", path)
    @element = Decoder.element(object, "element", path)
    @hint = Decoder.text?(object, "hint", path)
    @optional = Decoder.bool?(object, "optional", path)
    @dispatch_action = Decoder.bool?(object, "dispatch_action", path)
  end
end
