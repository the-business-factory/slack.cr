require "../../../support/block_kit/ui_only"

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Title")
section = Slack::UI::Checked::Blocks::Section.new(text: plain)
Slack::UI::Checked::Proof::FormModal.new(title: plain, blocks: [section])
