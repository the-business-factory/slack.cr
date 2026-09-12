require "../../../support/block_kit/ui_only"

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Button")
button = Slack::UI::Checked::BlockElements::Button.new(text: plain)
button.style = Slack::UI::Checked::BlockElements::ButtonStyle::Primary
