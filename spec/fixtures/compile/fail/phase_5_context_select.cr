require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
single = UI::BlockElements::StaticSelect.new(options: {option})
UI::Blocks::Context.new(elements: {single})
