require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
single = UI::BlockElements::StaticSelect.new(options: {option})
UI::Message.new(fallback_text: "Color", blocks: {UI::Blocks::Input.new(label: UI.plain("Color"), element: single)})
