# A pie chart. Slack requires 1 to 12 segments. Unique segment labels are
# library policy, taken from Slack's rich response guide; the block reference
# does not state it.
struct Slack::UI::DataVisualization::PieChart
  include Slack::UI::ValueValidation

  SEGMENTS_MAX_SIZE = 12

  @segments : Array(Segment)

  def initialize(segments : Enumerable(T)) forall T
    @segments = [] of Segment
    segments.each { |segment| append_segment(segment) }
    validate!
  end

  def type : String
    "pie"
  end

  def segments : Array(Segment)
    @segments.dup
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    if @segments.empty?
      issues << ValidationIssue.new("pie.segments.empty", "segments", "A pie chart must contain at least one segment.")
    elsif @segments.size > SEGMENTS_MAX_SIZE
      issues << ValidationIssue.new("pie.segments.too_many", "segments", "A pie chart cannot contain more than #{SEGMENTS_MAX_SIZE} segments.")
    end
    labels = Set(String).new
    @segments.each_with_index do |segment, index|
      segment.validate.each { |issue| issues << issue.at("segments[#{index}]") }
      next if labels.add?(segment.label)

      issues << ValidationIssue.new("pie.segment.label.duplicate", "segments[#{index}].label", "Segment labels must be unique within a pie chart.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "segments", @segments
    end
  end

  private def append_segment(segment : Segment) : Nil
    @segments << segment
  end
end
