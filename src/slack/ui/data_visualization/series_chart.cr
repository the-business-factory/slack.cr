# :nodoc:
# Shared fields and checks for bar, area, and line charts. Slack requires 1 to
# 12 series with unique names, and each series must have exactly one point for
# each category in `axis_config`. Point order in a series is free; category
# order sets the x-axis order.
module Slack::UI::DataVisualization::SeriesChart
  include Slack::UI::ValueValidation

  SERIES_MAX_SIZE = 12

  @series : Array(DataSeries)
  getter axis_config : AxisConfig

  def initialize(series : Enumerable(T), @axis_config : AxisConfig) forall T
    @series = [] of DataSeries
    series.each { |item| append_series(item) }
    validate!
  end

  def series : Array(DataSeries)
    @series.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    if @series.empty?
      issues << ValidationIssue.new("#{type}.series.empty", "series", "A #{type} chart must contain at least one series.")
    elsif @series.size > SERIES_MAX_SIZE
      issues << ValidationIssue.new("#{type}.series.too_many", "series", "A #{type} chart cannot contain more than #{SERIES_MAX_SIZE} series.")
    end
    categories = @axis_config.categories
    names = Set(String).new
    @series.each_with_index do |item, index|
      path = "series[#{index}]"
      item.validate.each { |issue| issues << issue.at(path) }
      unless names.add?(item.name)
        issues << ValidationIssue.new("#{type}.series.name.duplicate", "#{path}.name", "Series names must be unique within a chart.")
      end
      category_issues(issues, item, categories, path)
    end
    @axis_config.validate.each { |issue| issues << issue.at("axis_config") }
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "series", @series
      json.field "axis_config", @axis_config
    end
  end

  private def category_issues(issues : Array(ValidationIssue), item : DataSeries, categories : Array(String), path : String) : Nil
    seen = Set(String).new
    item.data.each_with_index do |point, index|
      label_path = "#{path}.data[#{index}].label"
      if !categories.includes?(point.label)
        issues << ValidationIssue.new("#{type}.series.data.unknown_category", label_path, "Data point label must match an axis category.")
      elsif !seen.add?(point.label)
        issues << ValidationIssue.new("#{type}.series.data.duplicate_category", label_path, "A series must contain one data point for each category.")
      end
    end
    missing = categories.reject { |category| seen.includes?(category) }
    return if missing.empty?

    issues << ValidationIssue.new("#{type}.series.data.missing_category", "#{path}.data",
      "A series must contain one data point for each category. Missing: #{missing.map(&.inspect).join(", ")}.")
  end

  private def append_series(item : DataSeries) : Nil
    @series << item
  end
end
