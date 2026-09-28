require "../../../../src/slack/ui"

alias UI = Slack::UI

UI::Blocks::Container.new(child_blocks: {UI::Blocks::Divider.new})
