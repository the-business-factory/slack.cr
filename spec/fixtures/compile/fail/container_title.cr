require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

UI::Blocks::Container.new(child_blocks: {UI::Blocks::Divider.new})
