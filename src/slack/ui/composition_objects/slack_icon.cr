# A built-in Slack icon. Slack accepts this object only in a card block.
struct Slack::UI::Checked::CompositionObjects::SlackIcon
  include Slack::UI::Checked::ValueValidation

  getter name : SlackIconName

  def initialize(@name : SlackIconName)
    validate!
  end

  def type : String
    "icon"
  end

  # `SlackIconName.new(Int)` can hold a value without a documented name.
  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    unless SlackIconName.valid?(@name)
      issues << ValidationIssue.new("slack_icon.name.invalid", "name", "Name must be one of Slack's documented icon names.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "name", @name.wire_value
    end
  end
end
