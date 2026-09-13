require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI.home(&.header(text: UI.mrkdwn("Heading")))
