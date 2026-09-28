struct Slack::Interactions::DatetimePickerValue
  getter raw : JSON::Any
  # Unix timestamp in seconds as received; use `Time.unix` to convert it.
  getter selected_date_time : Int64?

  def initialize(@raw : JSON::Any, path : String)
    object = PayloadAccess.object?(@raw, path) || raise TypeMismatch.new(path, "datetimepicker object", "null")
    actual = PayloadAccess.string?(object["type"]?, "#{path}.type")
    unless actual == "datetimepicker"
      raise TypeMismatch.new("#{path}.type", "datetimepicker", actual || "absent or null")
    end
    @selected_date_time = unix_seconds?(object["selected_date_time"]?, "#{path}.selected_date_time")
  end

  def type : String
    "datetimepicker"
  end

  def selected_date_time_presence : ValuePresence
    ValuePresence.of(@raw["selected_date_time"]?)
  end

  private def unix_seconds?(raw : JSON::Any?, path : String) : Int64?
    return if raw.nil? || raw.raw.nil?
    raw.as_i64? || raise TypeMismatch.new(path, "integer or null", raw.raw.class.to_s)
  end
end
