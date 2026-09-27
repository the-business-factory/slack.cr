require "../../../support/block_kit/ui_only"

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Title")
section = Slack::UI::Checked::Blocks::Section.new(text: plain)
common = Slack::UI::Checked::Proof::Input.new(
  Slack::UI::Checked::Proof::SyntheticCommonInput.new("shared")
)
home = Slack::UI::Checked::Proof::Input.new(
  Slack::UI::Checked::Proof::SyntheticHomeInput.new("home")
)
modal = Slack::UI::Checked::Proof::Input.new(
  Slack::UI::Checked::Proof::SyntheticModalInput.new("modal")
)

Slack::UI::Checked::Proof::Home.new(blocks: {section, common, home})
Slack::UI::Checked::Proof::FormModal.new(
  title: plain,
  submit: plain,
  blocks: {section, common, modal}
)
