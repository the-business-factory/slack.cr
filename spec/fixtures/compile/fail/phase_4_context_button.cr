require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Context.new(elements: [UI::BlockElements::Button.new(text: UI.plain("Button"))])
