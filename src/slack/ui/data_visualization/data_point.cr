# One y-axis value for an x-axis category. Slack permits negative values and
# requires a label of up to 20 characters that matches a category. A nonempty
# label and a finite value are library policy.
struct Slack::UI::DataVisualization::DataPoint
  include Slack::UI::ValueValidation

  LABEL_MAX_SIZE = 20

  getter label : String
  getter value : Int64 | Float64

  def initialize(@label : String, value : Int)
    @value = value.to_i64
    validate!
  end

  def initialize(@label : String, value : Float)
    @value = value.to_f64
    validate!
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    issues << ValidationIssue.new("data_point.label.empty", "label", "Label must not be empty.") if @label.empty?
    length_issue(issues, @label, LABEL_MAX_SIZE, "data_point.label.too_long", "label")
    value = @value
    if value.is_a?(Float64) && !value.finite?
      issues << ValidationIssue.new("data_point.value.not_finite", "value", "Value must be a finite number.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "label", @label
      json.field "value", @value
    end
  end
end
