module Slack::DecimalTimeStampConverter
  TS_FORMAT = "%s.%6N"

  def self.from_json(value : JSON::PullParser) : Time
    float_value = value.read_string.to_f
    seconds = float_value.to_i
    nanoseconds = ((float_value - seconds) * 1_000_000_000).to_i
    Time.unix(seconds) + nanoseconds.nanoseconds
  end

  def self.to_json(timestamp, builder)
    timestamp.to_s(TS_FORMAT).to_json(builder)
  end
end
