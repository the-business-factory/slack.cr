require "json"

# :nodoc:
# Reads Unix seconds sent as a JSON integer, like `Time::EpochConverter`. A
# value outside the `Time` range raises `JSON::ParseException`, as other
# malformed values do, so a Web API response reports it as malformed data.
module Slack::EpochConverter
  def self.from_json(pull : JSON::PullParser) : Time
    location = pull.location
    time(pull.read_int, location)
  end

  def self.to_json(value : Time, json : JSON::Builder) : Nil
    json.number(value.to_unix)
  end

  # Converts *seconds*, or raises `JSON::ParseException` at *location*.
  def self.time(seconds : Int64, location : {Int32, Int32}) : Time
    Time.unix(seconds)
  rescue OverflowError | ArgumentError
    raise JSON::ParseException.new("Unix time out of range", *location)
  end
end
