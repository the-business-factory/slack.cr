require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

input = UI::Blocks::Input.new(label: UI.plain("Input"), element: UI::BlockElements::PlainTextInput.new)
UI::DisplayModalBuilder.new(title: UI.plain("Display")).add(input)
