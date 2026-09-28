# A line chart. See `SeriesChart` for the series and category rules.
struct Slack::UI::Checked::DataVisualization::LineChart
  include Slack::UI::Checked::DataVisualization::SeriesChart

  def type : String
    "line"
  end
end
