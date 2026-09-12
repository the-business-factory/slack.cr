require "../../../support/block_kit/ui_only"

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Section")
section = Slack::UI::Checked::Blocks::Section.new(text: plain)
section.fields = [plain]
