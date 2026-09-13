class Slack::UI::Checked::DisplayModalBuilder
  @blocks = [] of DisplayModalBlock

  def initialize(
    @title : CompositionObjects::PlainText,
    @submit : CompositionObjects::PlainText? = nil,
    @close : CompositionObjects::PlainText? = nil,
    @private_metadata : String? = nil,
    @callback_id : String? = nil,
    @external_id : String? = nil,
    @clear_on_close : Bool? = nil,
    @notify_on_close : Bool? = nil,
    @submit_disabled : Bool? = nil,
  )
  end

  def add(block : DisplayModalBlock) : Nil
    @blocks << block
  end

  def add_all(blocks : Enumerable(T)) : Nil forall T
    DeclaredTypes.display_modal_block(T)
    blocks.each { |block| add(block) }
  end

  def section(
    text : Slack::UI::Checked::CompositionObjects::Text,
    accessory : Slack::UI::Checked::BlockElements::Button? = nil,
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

  def build : DisplayModal
    DisplayModal.new(
      blocks: @blocks,
      title: @title,
      submit: @submit,
      close: @close,
      private_metadata: @private_metadata,
      callback_id: @callback_id,
      external_id: @external_id,
      clear_on_close: @clear_on_close,
      notify_on_close: @notify_on_close,
      submit_disabled: @submit_disabled
    )
  end
end
