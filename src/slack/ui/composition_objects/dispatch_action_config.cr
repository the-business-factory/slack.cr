struct Slack::UI::CompositionObjects::DispatchActionConfig
  include Slack::InitializerMacros

  enum Triggerable
    OnInput
    OnEnter
    OnEither

    def to_s
      case self
      when .on_input?
        ["on_character_entered"]
      when .on_enter?
        ["on_enter_pressed"]
      when .on_either?
        ["on_enter_pressed", "on_character_entered"]
      else
        raise "Unreachable condition."
      end
    end
  end

  properties_with_initializer \
    trigger_actions_on : Triggerable = Triggerable::OnEnter

  def to_json(json : JSON::Builder)
    json.object do
      json.field "trigger_actions_on", trigger_actions_on.to_s
    end
  end
end
