class Slack::UI::Checked::FormModalBuilder
  include Slack::UI::Checked::DisplayBlockHelpers

  @blocks = [] of ModalBlock

  def initialize(
    @title : CompositionObjects::PlainText,
    @submit : CompositionObjects::PlainText,
    @close : CompositionObjects::PlainText? = nil,
    @private_metadata : String? = nil,
    @callback_id : String? = nil,
    @external_id : String? = nil,
    @clear_on_close : Bool? = nil,
    @notify_on_close : Bool? = nil,
    @submit_disabled : Bool? = nil,
  )
  end

  def add(block : ModalBlock) : Nil
    @blocks << block
  end

  def add_all(blocks : Enumerable(T)) : Nil forall T
    DeclaredTypes.form_modal_block(T)
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

  def input(
    label : CompositionObjects::PlainText,
    element : Blocks::InputElement,
    block_id : String? = nil,
    hint : CompositionObjects::PlainText? = nil,
    optional : Bool? = nil,
    dispatch_action : Bool? = nil,
  ) : Nil
    add(Blocks::Input.new(label: label, element: element, block_id: block_id, hint: hint, optional: optional, dispatch_action: dispatch_action))
  end

  def build : FormModal
    FormModal.new(
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
