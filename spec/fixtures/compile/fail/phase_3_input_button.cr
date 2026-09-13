require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Input.new(label: UI.plain("Input"), element: UI::BlockElements::Button.new(text: UI.plain("Button")))
