class Slack::UI::Checked::FormModalBuilder
  include Slack::UI::Checked::DisplayBlockHelpers
  include Slack::UI::Checked::InputBlockHelpers

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
