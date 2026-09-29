struct Slack::Interactions::MultiExternalSelectValue
  @selected_options : Array(SelectedOption)?
  getter selected_options_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "multi_external_select object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "multi_external_select"
      raise TypeMismatch.new("#{path}.type", "multi_external_select", actual || "absent or null")
    end
    selection = object["selected_options"]?
    @selected_options = if selection && !selection.raw.nil?
                          items = selection.as_a? || raise TypeMismatch.new("#{path}.selected_options", "array or null", selection.raw.class.to_s)
                          items.map_with_index { |item, index| SelectedOption.new(item, "#{path}.selected_options[#{index}]") }
                        end
    @selected_options_presence = ValuePresence.of(object["selected_options"]?)
  end

  def type : String
    "multi_external_select"
  end

  def selected_options : Array(SelectedOption)?
    @selected_options.try(&.dup)
  end
end
