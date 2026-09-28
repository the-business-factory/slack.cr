# A button that runs a workflow link trigger. Slack documents it in Section
# accessories and Actions blocks on messages only; Home and modal validation
# reject it.
struct Slack::UI::BlockElements::WorkflowButton
  include Slack::UI::ValueValidation

  getter text : Slack::UI::CompositionObjects::PlainText
  getter workflow : Slack::UI::CompositionObjects::Workflow
  getter action_id : String
  getter style : ButtonStyle?
  getter accessibility_label : String?

  def initialize(
    *,
    @text : Slack::UI::CompositionObjects::PlainText,
    @workflow : Slack::UI::CompositionObjects::Workflow,
    @action_id : String,
    @style : ButtonStyle? = nil,
    @accessibility_label : String? = nil,
  )
    validate!
  end

  def type : String
    "workflow_button"
  end

  def validate : Array(Slack::UI::ValidationIssue)
    issues = @text.validate.map(&.at("text"))
    length_issue(issues, @text.text, 75, "workflow_button.text.too_long", "text.text")
    issues.concat(@workflow.validate.map(&.at("workflow")))
    length_issue(issues, @action_id, 255, "workflow_button.action_id.too_long", "action_id")
    length_issue(issues, @accessibility_label, 75, "workflow_button.accessibility_label.too_long", "accessibility_label")
    if (style = @style) && !ButtonStyle.valid?(style)
      issues << Slack::UI::ValidationIssue.new("workflow_button.style.invalid", "style", "Style must be primary or danger.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "type", type
      json.field "text", @text
      json.field "action_id", @action_id
      json.field "workflow", @workflow
      json.field "style", @style.try(&.wire_value) if @style
      json.field "accessibility_label", @accessibility_label if @accessibility_label
    end
  end
end
