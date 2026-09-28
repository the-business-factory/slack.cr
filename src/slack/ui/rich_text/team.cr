# A workspace or team mention.
struct Slack::UI::RichText::Team
  include NodeValidation

  getter team_id : String
  getter style : Style?

  def initialize(@team_id : String, @style : Style? = nil)
    validate!
  end

  def type : String
    "team"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @team_id, "team.team_id.empty", "team_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "team_id", @team_id
      json.field "style", @style if @style
    end
  end
end
