struct Slack::UI::Checked::RichText::Emoji
  include NodeValidation

  getter name : String
  getter unicode : String?

  def initialize(@name : String, @unicode : String? = nil)
    validate!
  end

  def type : String
    "emoji"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @name, "emoji.name.empty", "name")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "name", @name
      json.field "unicode", @unicode if @unicode
    end
  end
end
