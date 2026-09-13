require "../../../../src/slack/ui"

section = Slack::UI::Checked::Blocks::Section.new(
  text: Slack::UI::Checked.plain("Immutable")
)
message = Slack::UI::Checked::Message.new(
  fallback_text: "Before",
  blocks: [section]
)
message.fallback_text = "After"
