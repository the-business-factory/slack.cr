require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked
option = UI::CompositionObjects::OverflowOption.new(text: UI.plain("Archive"), value: "archive")
UI::Blocks::Input.new(label: UI.plain("Action"), element: UI::BlockElements::Overflow.new(options: {option}))
