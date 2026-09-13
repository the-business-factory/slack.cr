enum Slack::UI::Checked::CompositionObjects::ConfirmationStyle
  Primary
  Danger

  def wire_value : String
    case self
    when .primary?
      "primary"
    when .danger?
      "danger"
    else
      raise Slack::UI::Checked::ValidationError.new([
        Slack::UI::Checked::ValidationIssue.new(
          code: "confirmation.style.invalid",
          path: "style",
          message: "Style must be primary or danger."
        ),
      ])
    end
  end
end
