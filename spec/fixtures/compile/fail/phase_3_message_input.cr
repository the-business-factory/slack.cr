require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

input = UI::Blocks::Input.new(label: UI.plain("Input"), element: UI::BlockElements::PlainTextInput.new)
UI::Message.new(fallback_text: "Input", blocks: [input])
