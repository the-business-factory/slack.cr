require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
option = UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one")
UI::CompositionObjects::OptionGroup.new(label: UI.mrkdwn("Group"), options: {option})
