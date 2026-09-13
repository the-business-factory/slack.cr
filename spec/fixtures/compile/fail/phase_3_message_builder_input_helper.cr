require "../../../../src/slack/ui"

Slack::UI::Checked::MessageBuilder.new(fallback_text: "Form").input(
  label: Slack::UI::Checked.plain("Note"), element: Slack::UI::Checked::BlockElements::PlainTextInput.new
)
