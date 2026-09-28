# A area chart. See `SeriesChart` for the series and category rules.
struct Slack::UI::Checked::DataVisualization::AreaChart
  include Slack::UI::Checked::DataVisualization::SeriesChart

  def type : String
    "area"
  end
end
