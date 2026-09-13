require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::DisplayModal.new(title: UI.mrkdwn("Title"), blocks: [] of UI::DisplayModalBlock)
