# One customizable input for a workflow link trigger. Slack checks that the
# name matches a customizable workflow input and that the value fits its type.
# End users can see these values; do not send secrets.
struct Slack::UI::CompositionObjects::WorkflowInputParameter
  getter name : String
  getter value : String

  def initialize(*, @name : String, @value : String)
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "name", @name
      json.field "value", @value
    end
  end
end
