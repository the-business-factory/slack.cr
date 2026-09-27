struct Slack::UI::Checked::FormModal
  include ModalContent

  getter title : CompositionObjects::PlainText
  getter submit : CompositionObjects::PlainText
  getter close : CompositionObjects::PlainText?
  getter private_metadata : String?
  getter callback_id : String?
  getter external_id : String?
  getter clear_on_close : Bool?
  getter notify_on_close : Bool?
  getter submit_disabled : Bool?

  @blocks : Array(ModalBlock)

  def initialize(
    blocks : Enumerable(T),
    @title : CompositionObjects::PlainText,
    @submit : CompositionObjects::PlainText,
    @close : CompositionObjects::PlainText? = nil,
    @private_metadata : String? = nil,
    @callback_id : String? = nil,
    @external_id : String? = nil,
    @clear_on_close : Bool? = nil,
    @notify_on_close : Bool? = nil,
    @submit_disabled : Bool? = nil,
  ) forall T
    DeclaredTypes.form_modal_block(T)
    @blocks = [] of ModalBlock
    blocks.each { |block| @blocks << block }
    validate!
  end

  def blocks : Array(ModalBlock)
    @blocks.dup
  end

  def snapshot : FormModal
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
