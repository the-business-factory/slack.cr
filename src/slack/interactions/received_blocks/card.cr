# A received `card` block.
# https://docs.slack.dev/reference/block-kit/blocks/card-block/
struct Slack::Interactions::ReceivedBlocks::Card
  getter raw : JSON::Any
  getter block_id : String?
  getter hero_image : ElementSummary?
  getter icon : ElementSummary?
  getter slack_icon : SlackIcon?
  getter title : ReceivedText?
  getter subtitle : ReceivedText?
  getter body : ReceivedText?
  getter subtext : ReceivedText?
  @actions : Array(ElementSummary)

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @hero_image = Decoder.element?(object, "hero_image", path)
    @icon = Decoder.element?(object, "icon", path)
    @slack_icon = Decoder.slack_icon?(object, "slack_icon", path)
    @title = Decoder.text?(object, "title", path)
    @subtitle = Decoder.text?(object, "subtitle", path)
    @body = Decoder.text?(object, "body", path)
    @subtext = Decoder.text?(object, "subtext", path)
    @actions = Decoder.elements(object, "actions", path, required: false)
  end

  def actions : Array(ElementSummary)
    @actions.dup
  end
end
