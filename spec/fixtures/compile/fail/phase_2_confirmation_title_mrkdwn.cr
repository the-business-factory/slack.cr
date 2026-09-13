require "../../../../src/slack/ui"

Slack::UI::Checked::CompositionObjects::Confirmation.new(
  title: Slack::UI::Checked.mrkdwn("*Title*"),
  text: Slack::UI::Checked.plain("Text"),
  confirm: Slack::UI::Checked.plain("Yes"),
  deny: Slack::UI::Checked.plain("No")
)
