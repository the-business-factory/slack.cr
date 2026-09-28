# A workflow link trigger URL with optional customizable input parameters.
# Slack checks that the URL belongs to a valid link trigger.
struct Slack::UI::Checked::CompositionObjects::WorkflowTrigger
  include Slack::UI::Checked::ValueValidation

  alias InputParameter = Slack::UI::Checked::CompositionObjects::WorkflowInputParameter

  getter url : String
  @customizable_input_parameters : Array(InputParameter)?

  def initialize(*, @url : String)
    @customizable_input_parameters = nil
    validate!
  end

  def initialize(*, @url : String, customizable_input_parameters : Enumerable(T)) forall T
    parameters = [] of InputParameter
    customizable_input_parameters.each { |parameter| append_parameter(parameters, parameter) }
    @customizable_input_parameters = parameters
    validate!
  end

  def customizable_input_parameters : Array(InputParameter)?
    @customizable_input_parameters.try(&.dup)
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if @url.empty?
      issues << Slack::UI::Checked::ValidationIssue.new("workflow_trigger.url.empty", "url", "Trigger URL must not be empty.")
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      json.field "url", @url
      json.field "customizable_input_parameters", @customizable_input_parameters if @customizable_input_parameters
    end
  end

  private def append_parameter(parameters : Array(InputParameter), parameter : InputParameter) : Nil
    parameters << parameter
  end
end
