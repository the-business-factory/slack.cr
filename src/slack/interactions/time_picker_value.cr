struct Slack::Interactions::TimePickerValue
  getter selected_time : String?
  getter timezone : String?
  getter timezone_presence : ValuePresence
  getter selected_time_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "timepicker object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "timepicker"
      raise TypeMismatch.new("#{path}.type", "timepicker", actual || "absent or null")
    end
    selection = object["selected_time"]?
    @selected_time = PayloadAccess.string?(selection, "#{path}.selected_time")
    @timezone = PayloadAccess.string?(object["timezone"]?, "#{path}.timezone")
    @timezone_presence = ValuePresence.of(object["timezone"]?)
    @selected_time_presence = ValuePresence.of(object["selected_time"]?)
  end

  def type : String
    "timepicker"
  end
end
