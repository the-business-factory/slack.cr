# A bar chart. See `SeriesChart` for the series and category rules.
struct Slack::UI::DataVisualization::BarChart
  include Slack::UI::DataVisualization::SeriesChart

  def type : String
    "bar"
  end
end
