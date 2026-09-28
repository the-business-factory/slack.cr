struct Slack::UI::Checked::RichText::Usergroup
  include NodeValidation

  getter usergroup_id : String
  getter style : Style?

  def initialize(@usergroup_id : String, @style : Style? = nil)
    validate!
  end

  def type : String
    "usergroup"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @usergroup_id, "usergroup.usergroup_id.empty", "usergroup_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "usergroup_id", @usergroup_id
      json.field "style", @style if @style
    end
  end
end
