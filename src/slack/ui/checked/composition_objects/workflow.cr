# The workflow that a workflow button runs, identified by its link trigger.
struct Slack::UI::Checked::CompositionObjects::Workflow
  include Slack::UI::Checked::ValueValidation

  getter trigger : WorkflowTrigger

  def initialize(*, @trigger : WorkflowTrigger)
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    @trigger.validate.map(&.at("trigger"))
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "trigger", @trigger
    end
  end
end
