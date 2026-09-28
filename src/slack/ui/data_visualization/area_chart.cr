# A area chart. See `SeriesChart` for the series and category rules.
struct Slack::UI::DataVisualization::AreaChart
  include Slack::UI::DataVisualization::SeriesChart

  def type : String
    "area"
  end
end
