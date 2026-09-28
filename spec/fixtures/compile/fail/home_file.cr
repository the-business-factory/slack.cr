require "../../../../src/slack/ui"

alias UI = Slack::UI

UI::Home.new(blocks: [UI::Blocks::File.new(external_id: "ABCD1")])
