class Slack::UI::Components::ButtonActions < Slack::UI::BaseComponent
  alias Styles = BlockElements::Button::Styles

  struct ButtonData
    include Slack::InitializerMacros

    properties_with_initializer text : String, style : Styles?
  end

  def self.render(
    action_id : String,
    buttons : Array(ButtonData)? = default_buttons
  )
    Slack::UI::Blocks::Actions.new(
      elements: buttons.map do |button|
        ButtonElement.render(
          action_id: "#{action_id}_#{button.text.downcase}",
          button_text: button.text,
          style: button.style
        )
      end
    )
  end

  def self.default_buttons
    [
      ButtonData.new("Ok", Styles::Primary),
      ButtonData.new("Cancel", Styles::Danger),
    ]
  end
end
