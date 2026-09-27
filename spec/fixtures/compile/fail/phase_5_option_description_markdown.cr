require "../../../../src/slack/ui"
alias UI = Slack::UI::Checked
UI::CompositionObjects::Option.new(text: UI.plain("One"), value: "one", description: UI.mrkdwn("Hint"))
