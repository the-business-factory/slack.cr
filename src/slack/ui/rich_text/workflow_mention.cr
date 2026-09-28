# A link that starts a workflow through one of its function triggers.
# Slack sets `channel_id` and `ts` on received mentions; they are not sent.
struct Slack::UI::RichText::WorkflowMention
  include NodeValidation

  getter workflow_id : String
  getter function_trigger_id : String
  getter text : String
  getter url : String?
  getter style : Style?

  def initialize(@workflow_id : String, @function_trigger_id : String, @text : String, @url : String? = nil, @style : Style? = nil)
    validate!
  end

  def type : String
    "workflow_mention"
  end

  def validate : Array(ValidationIssue)
    issues = [] of ValidationIssue
    empty_issue(issues, @workflow_id, "workflow_mention.workflow_id.empty", "workflow_id")
    empty_issue(issues, @function_trigger_id, "workflow_mention.function_trigger_id.empty", "function_trigger_id")
    empty_issue(issues, @text, "workflow_mention.text.empty", "text")
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "workflow_id", @workflow_id
      json.field "function_trigger_id", @function_trigger_id
      json.field "text", @text
      json.field "url", @url if @url
      json.field "style", @style if @style
    end
  end
end
