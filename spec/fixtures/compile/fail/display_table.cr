require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

table = UI::Blocks::Table.new(rows: { {UI::Table::RawText.new("Open")} })
UI::DisplayModal.new(title: UI.plain("Display"), blocks: [table, UI::Blocks::Divider.new])
