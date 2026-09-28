struct Slack::Interactions::DatePickerValue
  getter raw : JSON::Any
  getter selected_date : String?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "datepicker object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "datepicker"
      raise TypeMismatch.new("#{path}.type", "datepicker", actual || "absent or null")
    end
    selection = object["selected_date"]?
    @selected_date = PayloadAccess.string?(selection, "#{path}.selected_date")
  end

  def type : String
    "datepicker"
  end

  def selected_date_presence : ValuePresence
    ValuePresence.of(@raw["selected_date"]?)
  end
end
