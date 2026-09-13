require "../../../../src/slack"

alias UI = Slack::UI::Checked

UI::Home.new(blocks: [Slack::UI::Blocks::Header.from_json(%({"type":"header"}))])
