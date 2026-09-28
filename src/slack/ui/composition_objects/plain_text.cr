struct Slack::UI::CompositionObjects::PlainText
  MAX_LENGTH = 3000

  getter text : String
  getter emoji : Bool?

  def initialize(@text : String, @emoji : Bool? = nil)
    validate!
  end

  def type : String
    "plain_text"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @text.empty?
      issues << Slack::UI::ValidationIssue.new(
        code: "plain_text.text.empty",
        path: "text",
        message: "Text must not be empty."
      )
    elsif @text.size > MAX_LENGTH
      issues << Slack::UI::ValidationIssue.new(
        code: "plain_text.text.too_long",
        path: "text",
        message: "Text cannot be longer than #{MAX_LENGTH} characters."
      )
    end
    issues
  end

  def validate! : Nil
    issues = validate
    raise Slack::UI::ValidationError.new(issues) unless issues.empty?
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "text", @text
      json.field "emoji", @emoji unless @emoji.nil?
    end
  end
end
