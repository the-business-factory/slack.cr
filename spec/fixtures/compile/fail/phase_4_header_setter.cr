require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

value = UI::Blocks::Header.new(text: UI.plain("Heading"))
value.level = 2
