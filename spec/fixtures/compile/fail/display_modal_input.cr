require "../../../support/block_kit/ui_only"

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Title")
input = Slack::UI::Checked::Proof::Input.new(
  Slack::UI::Checked::Proof::SyntheticCommonInput.new("input")
)
Slack::UI::Checked::Proof::DisplayModal.new(title: plain, blocks: [input])
