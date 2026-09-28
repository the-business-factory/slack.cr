# Slack documents these Input children for modals and Home tabs only.
# Message and DisplayModal do not accept this block.
alias Slack::UI::Checked::Blocks::ViewInputElement = Slack::UI::Checked::BlockElements::RichTextInput

# An Input block for elements that Slack supports only in views. It has the
# same wire type, fields, and limits as `Input`; only Home and FormModal accept it.
struct Slack::UI::Checked::Blocks::ViewInput
  include Slack::UI::Checked::Blocks::InputContent

  getter label : Slack::UI::Checked::CompositionObjects::PlainText
  getter element : ViewInputElement
  getter block_id : String?
  getter hint : Slack::UI::Checked::CompositionObjects::PlainText?
  getter optional : Bool?
  getter dispatch_action : Bool?

  def initialize(
    @label : Slack::UI::Checked::CompositionObjects::PlainText,
    @element : ViewInputElement,
    @block_id : String? = nil,
    @hint : Slack::UI::Checked::CompositionObjects::PlainText? = nil,
    @optional : Bool? = nil,
    @dispatch_action : Bool? = nil,
  )
    validate!
  end
end
