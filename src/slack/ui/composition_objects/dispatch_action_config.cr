struct Slack::UI::CompositionObjects::DispatchActionConfig
  include Slack::InitializerMacros

  enum Triggerable
    OnInput
    OnEnter
    OnEither

    def wire_values : Array(String)
      case self
      when .on_input?
        ["on_character_entered"]
      when .on_enter?
        ["on_enter_pressed"]
      when .on_either?
        ["on_enter_pressed", "on_character_entered"]
      else
        raise Slack::Errors::InvalidUIBlock.new(
          "Dispatch action trigger is invalid"
        )
      end
    end

    def to_s : Array(String)
      wire_values
    end
  end

  properties_with_initializer \
    trigger_actions_on : Triggerable = Triggerable::OnEnter

  def after_initialize : Nil
    unless Triggerable.valid?(@trigger_actions_on)
      raise Errors::InvalidUIBlock.new("Dispatch action trigger is invalid")
    end
  end

  def to_json(json : JSON::Builder) : Nil
    json.object do
      json.field "trigger_actions_on", trigger_actions_on.wire_values
    end
  end
end
