enum Slack::UI::BlockElements::ButtonStyle
  Primary
  Danger

  def wire_value : String
    case self
    when .primary?
      "primary"
    when .danger?
      "danger"
    else
      raise Slack::UI::ValidationError.new([
        Slack::UI::ValidationIssue.new(
          code: "button.style.invalid",
          path: "style",
          message: "Style must be primary or danger."
        ),
      ])
    end
  end
end
