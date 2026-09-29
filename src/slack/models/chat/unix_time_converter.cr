# :nodoc:
# Reads Unix seconds sent as a JSON integer or as a string of digits. The
# `chat.scheduleMessage` reference shows `post_at` as a string, and
# `chat.scheduledMessages.list` shows it as an integer. A malformed or
# out-of-range value raises `JSON::ParseException`.
module Slack::Models::Chat::UnixTimeConverter
  def self.from_json(pull : JSON::PullParser) : Time
    location = pull.location
    seconds = pull.kind.string? ? pull.read_string.to_i64? : pull.read_int
    raise JSON::ParseException.new("Expected Unix seconds", *location) unless seconds
    Slack::EpochConverter.time(seconds, location)
  end

  def self.to_json(value : Time, json : JSON::Builder) : Nil
    json.number(value.to_unix)
  end
end
