require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::BlockElements::PlainTextInput.new(placeholder: UI.mrkdwn("Input"))
