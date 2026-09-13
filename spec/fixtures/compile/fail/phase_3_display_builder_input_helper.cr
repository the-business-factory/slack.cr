require "../../../../src/slack/ui"

Slack::UI::Checked::DisplayModalBuilder.new(title: Slack::UI::Checked.plain("Form")).input(
  label: Slack::UI::Checked.plain("Note"), element: Slack::UI::Checked::BlockElements::PlainTextInput.new
)
