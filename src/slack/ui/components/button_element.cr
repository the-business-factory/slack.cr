struct Slack::UI::Components::ButtonElement < Slack::UI::BaseComponent
  alias ConfirmationObject = Slack::UI::CompositionObjects::Confirmation
  alias Button = BlockElements::Button

  def self.render(action_id : String,
                  button_text : String,
                  confirm : ConfirmationObject? = nil,
                  style : Button::Styles? = nil) : Button
    Button.new(
      action_id: action_id,
      confirm: confirm,
      style: style,
      text: Button::Text.new(button_text)
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
