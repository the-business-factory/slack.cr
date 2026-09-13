require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::FormModalBuilder.new(title: UI.plain("Form"))
