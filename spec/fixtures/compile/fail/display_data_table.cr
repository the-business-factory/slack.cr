require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

table = UI::Blocks::DataTable.new(caption: "Queue", header: {UI::Table::RawText.new("Ticket")}, rows: { {UI::Table::RawText.new("T-1")} })
UI::DisplayModal.new(title: UI.plain("Display"), blocks: [table, UI::Blocks::Divider.new])
