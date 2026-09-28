require "../../../../src/slack/ui"

alias UI = Slack::UI

input = UI::Blocks::Input.new(label: UI.plain("Input"), element: UI::BlockElements::PlainTextInput.new)
UI::FormModal.new(title: UI.plain("Form"), blocks: [input])
