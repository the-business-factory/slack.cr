require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Header.new(text: UI.mrkdwn("Heading"))
