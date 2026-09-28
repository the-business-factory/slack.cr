struct Slack::Interactions::TimePickerValue
  getter raw : JSON::Any
  getter selected_time : String?
  getter timezone : String?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "timepicker object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "timepicker"
      raise TypeMismatch.new("#{path}.type", "timepicker", actual || "absent or null")
    end
    selection = object["selected_time"]?
    @selected_time = PayloadAccess.string?(selection, "#{path}.selected_time")
    @timezone = PayloadAccess.string?(object["timezone"]?, "#{path}.timezone")
  end

  def timezone_presence : ValuePresence
    ValuePresence.of(@raw["timezone"]?)
  end

  def type : String
    "timepicker"
  end

  def selected_time_presence : ValuePresence
    ValuePresence.of(@raw["selected_time"]?)
  end
end
