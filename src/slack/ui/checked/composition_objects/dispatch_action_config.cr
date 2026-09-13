struct Slack::UI::Checked::CompositionObjects::DispatchActionConfig
  include Slack::UI::Checked::ValueValidation

  @trigger_actions_on : Array(DispatchTrigger)?

  def initialize(trigger_actions_on : Enumerable(T)) forall T
    {% unless T <= Slack::UI::Checked::CompositionObjects::DispatchTrigger %}
      {% raise "checked dispatch config rejects its declared trigger item type" %}
    {% end %}
    @trigger_actions_on = trigger_actions_on.map { |trigger| trigger }.to_a
    validate!
  end

  def initialize
    @trigger_actions_on = nil
  end

  def trigger_actions_on : Array(DispatchTrigger)?
    @trigger_actions_on.try(&.dup)
  end

  def validate : Array(Slack::UI::Checked::ValidationIssue)
    issues = [] of Slack::UI::Checked::ValidationIssue
    if triggers = @trigger_actions_on
      if triggers.empty? || triggers.size > 2 || triggers.uniq.size != triggers.size
        issues << Slack::UI::Checked::ValidationIssue.new("dispatch_action_config.triggers.invalid", "trigger_actions_on", "Supply one or both distinct dispatch triggers, or omit the field.")
      end
      triggers.each_with_index do |trigger, index|
        unless DispatchTrigger.valid?(trigger)
          issues << Slack::UI::Checked::ValidationIssue.new("dispatch_action_config.trigger.invalid", "trigger_actions_on[#{index}]", "Unknown dispatch trigger.")
        end
      end
    end
    issues
  end

  def to_json(json : JSON::Builder) : Nil
    validate!
    json.object do
      if triggers = @trigger_actions_on
        json.field "trigger_actions_on", triggers.map(&.wire_value)
      end
    end
  end
end
