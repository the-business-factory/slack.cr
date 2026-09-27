class Slack::UI::Checked::MessageBuilder
  include Slack::UI::Checked::DisplayBlockHelpers

  @blocks : Array(MessageBlock)
  @fallback_text : String?

  def initialize(@fallback_text : String)
    @blocks = [] of MessageBlock
  end

  def self.with_slack_generated_fallback : MessageBuilder
    new(fallback_text: nil)
  end

  private def initialize(@fallback_text : Nil)
    @blocks = [] of MessageBlock
  end

  def add(block : MessageBlock) : Nil
    @blocks << block
  end

  def add_all(blocks : Enumerable(T)) : Nil forall T
    Slack::UI::Checked::DeclaredTypes.message_block(T)
    blocks.each { |block| add(block) }
  end

  def section(
    text : Slack::UI::Checked::CompositionObjects::Text,
    accessory : Slack::UI::Checked::Blocks::Section::Accessory? = nil,
    block_id : String? = nil,
    expand : Bool? = nil,
  ) : Nil
    add(Slack::UI::Checked::Blocks::Section.new(
      text: text,
      accessory: accessory,
      block_id: block_id,
      expand: expand
    ))
  end

  def actions(elements : Enumerable(T), block_id : String? = nil) : Nil forall T
    add(Slack::UI::Checked::Blocks::Actions.new(elements: elements, block_id: block_id))
  end

  def divider(block_id : String? = nil) : Nil
    add(Slack::UI::Checked::Blocks::Divider.new(block_id: block_id))
  end

  def build : Message
    if fallback_text = @fallback_text
      Message.new(fallback_text: fallback_text, blocks: @blocks)
    else
      Message.with_slack_generated_fallback(blocks: @blocks)
    end
  end
end
