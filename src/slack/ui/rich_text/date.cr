# A localized date. Slack substitutes tokens such as `{date_short}` in `format`.
struct Slack::UI::Checked::RichText::Date
  include NodeValidation

  getter timestamp : Int64
  getter format : String
  getter url : String?
  getter fallback : String?
  getter style : Style?
  getter timezone : String?

  def initialize(@timestamp : Int64, @format : String, @url : String? = nil, @fallback : String? = nil, @style : Style? = nil,
                 @timezone : String? = nil)
    validate!
  end

  def type : String
    "date"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @format, "date.format.empty", "format")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "timestamp", @timestamp
      json.field "format", @format
      json.field "timezone", @timezone if @timezone
      json.field "url", @url if @url
      json.field "fallback", @fallback if @fallback
      json.field "style", @style if @style
    end
  end
end
