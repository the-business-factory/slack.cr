module Slack::UI::Checked::BlockElements
  enum ButtonStyle
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
            code: "button.style.invalid",
            path: "style",
            message: "Style must be primary or danger."
          ),
        ])
      end
    end
  end

  struct Button
    getter text : CompositionObjects::PlainText
    getter action_id : String?
    getter style : ButtonStyle?

    def initialize(
      @text : CompositionObjects::PlainText,
      @action_id : String? = nil,
      @style : ButtonStyle? = nil,
    )
      validate!
    end

    def validate : Array(Slack::UI::Checked::ValidationIssue)
      issues = [] of Slack::UI::Checked::ValidationIssue
      if (style = @style) && !ButtonStyle.valid?(style)
        issues << Slack::UI::Checked::ValidationIssue.new(
          code: "button.style.invalid",
          path: "style",
          message: "Style must be primary or danger."
        )
      end
      issues
    end

    def validate! : Nil
      issues = validate
      raise Slack::UI::Checked::ValidationError.new(issues) unless issues.empty?
    end

    def to_json(json : JSON::Builder) : Nil
      validate!
      json.object do
        json.field "type", "button"
        json.field "text", @text
        json.field "action_id", @action_id if @action_id
        json.field "style", @style.try(&.wire_value) if @style
      end
    end
  end
end
