# One pie chart slice. Slack requires a label of up to 20 characters and a
# value greater than 0. A nonempty label and a finite value are library policy.
struct Slack::UI::Checked::DataVisualization::Segment
  include Slack::UI::Checked::ValueValidation

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
    issues << ValidationIssue.new("segment.label.empty", "label", "Label must not be empty.") if @label.empty?
    length_issue(issues, @label, LABEL_MAX_SIZE, "segment.label.too_long", "label")
    value = @value
    if value.is_a?(Float64) && !value.finite?
      issues << ValidationIssue.new("segment.value.not_finite", "value", "Value must be a finite number.")
    elsif value <= 0
      issues << ValidationIssue.new("segment.value.not_positive", "value", "Value must be greater than 0.")
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
