require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked
option = UI::CompositionObjects::OverflowOption.new(text: UI.plain("Details"), value: "details", url: "https://example.com")
UI::BlockElements::StaticSelect.new(options: {option})
