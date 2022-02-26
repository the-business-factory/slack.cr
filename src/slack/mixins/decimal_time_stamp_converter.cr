module Slack::DecimalTimeStampConverter
  TS_FORMAT = "%s.%6N"

  def self.from_json(value : JSON::PullParser) : Time
    Time.parse!(value.read_string, TS_FORMAT)
  end

  def self.to_json(timestamp, builder)
    timestamp.to_s(TS_FORMAT).to_json(builder)
  end
end
