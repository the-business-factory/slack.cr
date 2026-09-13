require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::BlockElements::PlainTextInput.new.min_length = -1
