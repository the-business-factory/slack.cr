class Slack::UI::Components::InputElement < Slack::UI::BaseComponent
  alias Input = Blocks::Input
  alias PlainTextInput = BlockElements::PlainTextInput

  def self.render(action_id : String,
                  label_text : String,
                  placeholder_text : String,
                  initial_value : String? = nil,
                  dispatch_action : Bool = false,
                  multiline : Bool = false)
    Input.new(
      label: Input::Label.new(label_text),
      dispatch_action: dispatch_action,
      element: PlainTextInput.new(
        action_id: action_id,
        placeholder: PlainTextInput::Placeholder.new(placeholder_text),
        initial_value: initial_value,
        multiline: multiline
      )
    )
  end
end
