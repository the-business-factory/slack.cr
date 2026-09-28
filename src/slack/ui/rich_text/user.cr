struct Slack::UI::RichText::User
  include NodeValidation

  getter user_id : String
  getter style : Style?

  def initialize(@user_id : String, @style : Style? = nil)
    validate!
  end

  def type : String
    "user"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @user_id, "user.user_id.empty", "user_id")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "user_id", @user_id
      json.field "style", @style if @style
    end
  end
end
