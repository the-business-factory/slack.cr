enum Slack::UI::CompositionObjects::DispatchTrigger
  OnEnterPressed
  OnCharacterEntered

  def wire_value : String
    case self
    when .on_enter_pressed?     then "on_enter_pressed"
    when .on_character_entered? then "on_character_entered"
    else
      raise Slack::UI::ValidationError.new([
        Slack::UI::ValidationIssue.new("dispatch_action_config.trigger.invalid", "trigger_actions_on", "Unknown dispatch trigger."),
      ])
    end
  end
end
