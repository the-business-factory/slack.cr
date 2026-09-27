require "../../../support/block_kit/ui_only"

struct ForbiddenAccessory
end

plain = Slack::UI::Checked::CompositionObjects::PlainText.new("Text")
Slack::UI::Checked::Blocks::Section.new(text: plain, accessory: ForbiddenAccessory.new)
