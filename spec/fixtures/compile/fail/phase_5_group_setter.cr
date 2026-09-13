require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
group = UI::CompositionObjects::OptionGroup.new(label: UI.plain("Group"), options: {option})
group.options = [option]
