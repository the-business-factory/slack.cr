module Slack::DecimalTimeStampConverter
  TS_FORMAT = "%s.%6N"

  # Raises `JSON::ParseException` for a string that is not a decimal number
  # or is outside the `Time` range.
  def self.from_json(value : JSON::PullParser) : Time
    location = value.location
    float_value = value.read_string.to_f?
    unless float_value && float_value.finite?
      raise JSON::ParseException.new("Expected a decimal timestamp", *location)
    end
    begin
      seconds = float_value.to_i64
      nanoseconds = ((float_value - seconds) * 1_000_000_000).to_i
      Time.unix(seconds) + nanoseconds.nanoseconds
    rescue OverflowError | ArgumentError
      raise JSON::ParseException.new("Decimal timestamp out of range", *location)
    end
  end

  def self.to_json(timestamp, builder)
    timestamp.to_s(TS_FORMAT).to_json(builder)
  end
end
