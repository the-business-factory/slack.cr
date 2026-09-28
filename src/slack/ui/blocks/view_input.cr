# Slack documents these Input children for modals and Home tabs only.
# Message and DisplayModal do not accept this block.
alias Slack::UI::Blocks::ViewInputElement = Slack::UI::BlockElements::RichTextInput

# An Input block for elements that Slack supports only in views. It has the
# same wire type, fields, and limits as `Input`; only Home and FormModal accept it.
struct Slack::UI::Blocks::ViewInput
  include Slack::UI::Blocks::InputContent

  getter label : Slack::UI::CompositionObjects::PlainText
  getter element : ViewInputElement
  getter block_id : String?
  getter hint : Slack::UI::CompositionObjects::PlainText?
  getter optional : Bool?
  getter dispatch_action : Bool?

  def initialize(
    @label : Slack::UI::CompositionObjects::PlainText,
    @element : ViewInputElement,
    @block_id : String? = nil,
    @hint : Slack::UI::CompositionObjects::PlainText? = nil,
    @optional : Bool? = nil,
    @dispatch_action : Bool? = nil,
  )
    validate!
  end
end
