struct Slack::Interactions::RadioButtonsValue
  getter raw : JSON::Any
  getter selected_option : SelectedOption?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "radio_buttons object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "radio_buttons"
      raise TypeMismatch.new("#{path}.type", "radio_buttons", actual || "absent or null")
    end
    selection = object["selected_option"]?
    @selected_option = SelectedOption.new(selection, "#{path}.selected_option") if selection && !selection.raw.nil?
  end

  def type : String
    "radio_buttons"
  end

  def selected_option_presence : ValuePresence
    ValuePresence.of(@raw["selected_option"]?)
  end
end
