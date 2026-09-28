require "../../../../src/slack/ui"

alias UI = Slack::UI

chart = UI::DataVisualization::PieChart.new({UI::DataVisualization::Segment.new("Open", 1)})
UI::DisplayModal.new(title: UI.plain("Display"), blocks: [UI::Blocks::DataVisualization.new("Tickets", chart), UI::Blocks::Divider.new])
