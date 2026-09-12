require "../../../support/block_kit/ui_only"

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Title")
home_input = Slack::UI::Checked::Proof::Input.new(
  Slack::UI::Checked::Proof::SyntheticHomeInput.new("home only")
)
Slack::UI::Checked::Proof::FormModal.new(
  title: plain,
  submit: plain,
  blocks: [home_input]
)
