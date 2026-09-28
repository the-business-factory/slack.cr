# A named series of data points for a bar, area, or line chart. Slack requires
# a name of up to 20 characters and 1 to 20 points. The chart checks that the
# points match its categories. A nonempty name is library policy.
struct Slack::UI::DataVisualization::DataSeries
  include Slack::UI::ValueValidation

  NAME_MAX_SIZE = 20
  DATA_MAX_SIZE = 20

  getter name : String
  @data : Array(DataPoint)

  def initialize(@name : String, data : Enumerable(T)) forall T
    @data = [] of DataPoint
    data.each { |point| append_point(point) }
    validate!
  end

  def data : Array(DataPoint)
    @data.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    issues << ValidationIssue.new("data_series.name.empty", "name", "Name must not be empty.") if @name.empty?
    length_issue(issues, @name, NAME_MAX_SIZE, "data_series.name.too_long", "name")
    if @data.empty?
      issues << ValidationIssue.new("data_series.data.empty", "data", "A data series must contain at least one data point.")
    elsif @data.size > DATA_MAX_SIZE
      issues << ValidationIssue.new("data_series.data.too_many", "data", "A data series cannot contain more than #{DATA_MAX_SIZE} data points.")
    end
    @data.each_with_index do |point, index|
      point.validate.each { |issue| issues << issue.at("data[#{index}]") }
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "name", @name
      json.field "data", @data
    end
  end

  private def append_point(point : DataPoint) : Nil
    @data << point
  end
end
