struct Slack::Interactions::ExternalSelectValue
  getter raw : JSON::Any
  getter selected_option : SelectedOption?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "external_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "external_select"
      raise TypeMismatch.new("#{path}.type", "external_select", actual || "absent or null")
    end
    selection = object["selected_option"]?
    @selected_option = SelectedOption.new(selection, "#{path}.selected_option") if selection && !selection.raw.nil?
  end

  def type : String
    "external_select"
  end

  def selected_option_presence : ValuePresence
    ValuePresence.of(@raw["selected_option"]?)
  end
end
