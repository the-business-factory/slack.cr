require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

container = UI::Blocks::Container.new(title: UI.plain("Group"), child_blocks: {UI::Blocks::Divider.new})
UI::DisplayModal.new(title: UI.plain("Display"), blocks: [container, UI::Blocks::Divider.new])
