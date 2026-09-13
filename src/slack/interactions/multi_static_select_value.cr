struct Slack::Interactions::MultiStaticSelectValue
  getter raw : JSON::Any
  @selected_options : Array(SelectedOption)?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "multi_static_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "multi_static_select"
      raise TypeMismatch.new("#{path}.type", "multi_static_select", actual || "absent or null")
    end
    selection = object["selected_options"]?
    @selected_options = if selection && !selection.raw.nil?
                          items = selection.as_a? || raise TypeMismatch.new("#{path}.selected_options", "array or null", selection.raw.class.to_s)
                          items.map_with_index { |item, index| SelectedOption.new(item, "#{path}.selected_options[#{index}]") }
                        end
  end

  def type : String
    "multi_static_select"
  end

  def selected_options_presence : ValuePresence
    ValuePresence.of(@raw["selected_options"]?)
  end

  def selected_options : Array(SelectedOption)?
    @selected_options.try(&.dup)
  end
end
