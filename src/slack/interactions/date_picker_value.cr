struct Slack::Interactions::DatePickerValue
  getter selected_date : String?
  getter selected_date_presence : ValuePresence

  def initialize(raw : JSON::Any, path : String)
    object = PayloadAccess.object?(raw, path) || raise TypeMismatch.new(path, "datepicker object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "datepicker"
      raise TypeMismatch.new("#{path}.type", "datepicker", actual || "absent or null")
    end
    selection = object["selected_date"]?
    @selected_date = PayloadAccess.string?(selection, "#{path}.selected_date")
    @selected_date_presence = ValuePresence.of(object["selected_date"]?)
  end

  def type : String
    "datepicker"
  end
end
