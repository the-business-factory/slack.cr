struct Slack::UI::Components::ConfirmationDialog < Slack::UI::BaseComponent
  def self.render(title : String,
                  text : String,
                  confirm : String,
                  deny : String) : CompositionObjects::Confirmation
    CompositionObjects::Confirmation.new(
      title: CompositionObjects::Confirmation::Title.new(title),
      text: CompositionObjects::Confirmation::Text.new(text),
      confirm: CompositionObjects::Confirmation::Confirm.new(confirm),
      deny: CompositionObjects::Confirmation::Deny.new(deny)
    )
  end
end
