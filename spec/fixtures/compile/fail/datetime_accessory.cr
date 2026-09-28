require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked
UI::Blocks::Section.new(text: UI.plain("Start"), accessory: UI::BlockElements::DatetimePicker.new)
