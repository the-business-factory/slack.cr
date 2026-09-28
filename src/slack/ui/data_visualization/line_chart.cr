# A line chart. See `SeriesChart` for the series and category rules.
struct Slack::UI::DataVisualization::LineChart
  include Slack::UI::DataVisualization::SeriesChart

  def type : String
    "line"
  end
end
