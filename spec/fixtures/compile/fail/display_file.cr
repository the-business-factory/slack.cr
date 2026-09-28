require "../../../../src/slack/ui"

alias UI = Slack::UI

blocks = [UI::Blocks::File.new(external_id: "ABCD1"), UI::Blocks::Divider.new]
UI::DisplayModal.new(title: UI.plain("Display"), blocks: blocks)
