# A new title for the plan of a stream in `TaskDisplayMode::Plan`.
struct Slack::Api::Streaming::PlanUpdateChunk
  include Slack::UI::ValueValidation

  TITLE_MAX_SIZE = 256

  getter title : String

  def initialize(@title : String)
    validate!
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @title.empty?
      issues << Slack::UI::ValidationIssue.new("plan_update.title.empty", "title", "Title must not be empty.")
    end
    length_issue(issues, @title, TITLE_MAX_SIZE, "plan_update.title.too_long", "title")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", "plan_update"
      json.field "title", @title
    end
  end
end
