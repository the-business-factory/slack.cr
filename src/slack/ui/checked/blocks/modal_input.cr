# Slack documents these Input children for modals only. Message, Home, and
# DisplayModal do not accept this block.
alias Slack::UI::Checked::Blocks::ModalInputElement = Slack::UI::Checked::BlockElements::NumberInput

# An Input block for elements that Slack supports only in modals. It has the
# same wire type, fields, and limits as `Input`; only FormModal accepts it.
struct Slack::UI::Checked::Blocks::ModalInput
  include Slack::UI::Checked::Blocks::InputContent

  getter label : Slack::UI::Checked::CompositionObjects::PlainText
  getter element : ModalInputElement
  getter block_id : String?
  getter hint : Slack::UI::Checked::CompositionObjects::PlainText?
  getter optional : Bool?
  getter dispatch_action : Bool?

  def initialize(
    @label : Slack::UI::Checked::CompositionObjects::PlainText,
    @element : ModalInputElement,
    @block_id : String? = nil,
    @hint : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @optional : Bool? = nil,
    @dispatch_action : Bool? = nil,
  )
    validate!
  end
end
