require "../../../../src/slack/ui"

alias UI = Slack::UI::Checked

rich = UI::Blocks::RichText.new(elements: {UI::RichText::Section.new(elements: {UI::RichText::Text.new("Owner")})})
UI::Blocks::DataTable.new(caption: "Owners", header: {rich}, rows: { {UI::Table::RawText.new("U-1")} })
