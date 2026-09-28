# A received `container` block. Child blocks decode like top-level blocks.
# https://docs.slack.dev/reference/block-kit/blocks/container-block
struct Slack::Interactions::ReceivedBlocks::Container
  getter raw : JSON::Any
  getter block_id : String?
  getter title : ReceivedText?
  getter rich_text_title : RichText::Block?
  getter subtitle : ReceivedText?
  # The width name, such as `standard` or `wide`.
  getter width : String?
  getter icon : ElementSummary?
  getter is_collapsible : Bool?
  getter default_collapsed : Bool?
  getter has_header_divider : Bool?
  @child_blocks : Array(ReceivedBlock)

  def initialize(@raw : JSON::Any, object : Hash(String, JSON::Any), path : String)
    @block_id = Decoder.block_id(object, path)
    @title = Decoder.text?(object, "title", path)
    @rich_text_title = Decoder.rich_text?(object, "rich_text_title", path)
    @subtitle = Decoder.text?(object, "subtitle", path)
    @width = Decoder.string?(object, "width", path)
    @icon = Decoder.element?(object, "icon", path)
    @is_collapsible = Decoder.bool?(object, "is_collapsible", path)
    @default_collapsed = Decoder.bool?(object, "default_collapsed", path)
    @has_header_divider = Decoder.bool?(object, "has_header_divider", path)
    @child_blocks = Decoder.blocks(object, "child_blocks", path)
  end

  def child_blocks : Array(ReceivedBlock)
    @child_blocks.dup
  end
end
