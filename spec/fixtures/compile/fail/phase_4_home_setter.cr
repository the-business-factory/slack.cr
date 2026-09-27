require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

value = UI.home { |_builder| }
value.blocks = [] of UI::HomeBlock
