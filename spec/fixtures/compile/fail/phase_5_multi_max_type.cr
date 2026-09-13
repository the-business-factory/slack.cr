require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
UI::BlockElements::MultiStaticSelect.new(options: {option}, max_selected_items: "2")
