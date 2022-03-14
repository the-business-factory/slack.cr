class Slack::UI::Components::Button < Slack::UI::BaseComponent
  alias ConfirmationObject = Slack::UI::CompositionObjects::Confirmation
  alias ButtonElement = BlockElements::Button

  def self.render(action_id : String,
                  button_text : String,
                  confirm : ConfirmationObject? = nil,
                  style : ButtonElement::Styles? = nil) : ButtonElement
    ButtonElement.new(
      action_id: action_id,
      confirm: confirm,
      style: style,
      text: ButtonElement::Text.new(button_text)
    )
  end

  def self.default_dialog
    ConfirmationDialog.render(
      confirm: "Confirm",
      text: "Are you sure?",
      deny: "Cancel",
      title: "Title"
    )
  end
end
