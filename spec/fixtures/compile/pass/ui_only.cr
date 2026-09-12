require "../../../support/block_kit/ui_only"

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("No credentials")
section = Slack::UI::Checked::Blocks::Section.new(text: plain)
modal = Slack::UI::Checked::Proof::DisplayModal.new(title: plain, blocks: [section])

raise "UI-only payload failed" unless JSON.parse(modal.to_json)["type"] == "modal"
