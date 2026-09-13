require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
UI::BlockElements::StaticSelect.new(options: {option}, initial_options: {option})
