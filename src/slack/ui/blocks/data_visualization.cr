alias Slack::UI::DataVisualization::Chart = Slack::UI::DataVisualization::PieChart |
                                            Slack::UI::DataVisualization::BarChart |
                                            Slack::UI::DataVisualization::AreaChart |
                                            Slack::UI::DataVisualization::LineChart

# A titled pie, bar, area, or line chart that Slack renders. Slack lists
# messages and Home tabs as its surfaces, so modal unions exclude it. Slack
# permits at most two of these blocks in one message; `Message` checks this.
# A nonempty title is library policy.
struct Slack::UI::Blocks::DataVisualization
  include Slack::UI::ValueValidation

  TITLE_MAX_SIZE = 50

  getter title : String
  getter chart : Slack::UI::DataVisualization::Chart
  getter block_id : String?

  def initialize(@title : String, @chart : Slack::UI::DataVisualization::Chart, @block_id : String? = nil)
    validate!
  end

  def type : String
    "data_visualization"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    issues << ValidationIssue.new("data_visualization.title.empty", "title", "Title must not be empty.") if @title.empty?
    length_issue(issues, @title, TITLE_MAX_SIZE, "data_visualization.title.too_long", "title")
    @chart.validate.each { |issue| issues << issue.at("chart") }
    length_issue(issues, @block_id, 255, "data_visualization.block_id.too_long", "block_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "block_id", @block_id if @block_id
      json.field "title", @title
      json.field "chart", @chart
    end
  end
end
