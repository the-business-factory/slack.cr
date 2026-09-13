require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

value = UI::CompositionObjects::SlackFile.new(id: "F123")
value.id = "F456"
