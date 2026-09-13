require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Input.new(label: UI.mrkdwn("Input"), element: UI::BlockElements::PlainTextInput.new)
