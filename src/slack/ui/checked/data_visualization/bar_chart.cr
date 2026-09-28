# A bar chart. See `SeriesChart` for the series and category rules.
struct Slack::UI::Checked::DataVisualization::BarChart
  include Slack::UI::Checked::DataVisualization::SeriesChart

  def type : String
    "bar"
  end
end
