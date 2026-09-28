# Slack documents these Input children for modals only. Message, Home, and
# DisplayModal do not accept this block.
alias Slack::UI::Blocks::ModalInputElement = Slack::UI::BlockElements::NumberInput | Slack::UI::BlockElements::UrlInput | Slack::UI::BlockElements::FileInput | Slack::UI::BlockElements::EmailInput

# An Input block for elements that Slack supports only in modals. It has the
# same wire type, fields, and limits as `Input`; only FormModal accepts it.
struct Slack::UI::Blocks::ModalInput
  include Slack::UI::Blocks::InputContent

  getter label : Slack::UI::CompositionObjects::PlainText
  getter element : ModalInputElement
  getter block_id : String?
  getter hint : Slack::UI::CompositionObjects::PlainText?
  getter optional : Bool?
  getter dispatch_action : Bool?

  def initialize(
    @label : Slack::UI::CompositionObjects::PlainText,
    @element : ModalInputElement,
    @block_id : String? = nil,
    @hint : Slack::UI::CompositionObjects::PlainText? = nil,
    @optional : Bool? = nil,
    @dispatch_action : Bool? = nil,
  )
    validate!
  end

  # Slack rejects dispatch_action true for file_input, which never dispatches block actions.
  def validate : Array(Slack::UI::ValidationIssue)
    issues = super
    if @dispatch_action && @element.is_a?(Slack::UI::BlockElements::FileInput)
      issues << Slack::UI::ValidationIssue.new("input.dispatch_action.unsupported", "dispatch_action", "A file_input element cannot dispatch block actions.")
    end
    issues
  end
end
