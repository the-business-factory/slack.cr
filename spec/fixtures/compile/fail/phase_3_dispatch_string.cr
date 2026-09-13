require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::CompositionObjects::DispatchActionConfig.new(trigger_actions_on: ["on_enter_pressed"])
