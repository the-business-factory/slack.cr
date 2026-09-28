# A numeric table cell. Slack uses `value` as the number and shows `text`.
# Integers stay integers on the wire. Nonempty text and a finite value are
# library policy; JSON cannot encode NaN or infinity.
struct Slack::UI::Checked::Table::RawNumber
  include Slack::UI::Checked::ValueValidation

  getter value : Int64 | Float64
  getter text : String

  def initialize(value : Int, @text : String)
    @value = value.to_i64
    validate!
  end

  def initialize(value : Float, @text : String)
    @value = value.to_f64
    validate!
  end

  def type : String
    "raw_number"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    value = @value
    if value.is_a?(Float64) && !value.finite?
      issues << ValidationIssue.new("raw_number.value.not_finite", "value", "Value must be a finite number.")
    end
    issues << ValidationIssue.new("raw_number.text.empty", "text", "Text must not be empty.") if @text.empty?
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "value", @value
      json.field "text", @text
    end
  end
end
