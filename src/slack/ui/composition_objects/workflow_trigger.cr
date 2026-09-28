# A workflow link trigger URL with optional customizable input parameters.
# Slack checks that the URL belongs to a valid link trigger.
struct Slack::UI::CompositionObjects::WorkflowTrigger
  include Slack::UI::ValueValidation

  alias InputParameter = Slack::UI::CompositionObjects::WorkflowInputParameter

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

  def validate : Array(Slack::UI::ValidationIssue)
    issues = [] of Slack::UI::ValidationIssue
    if @url.empty?
      issues << Slack::UI::ValidationIssue.new("workflow_trigger.url.empty", "url", "Trigger URL must not be empty.")
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
