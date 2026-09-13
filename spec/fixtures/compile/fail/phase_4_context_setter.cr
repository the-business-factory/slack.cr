require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

value = UI::Blocks::Context.new(elements: [UI.plain("Context")])
value.elements = [UI.plain("New")]
