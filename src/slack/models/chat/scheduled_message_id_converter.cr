# :nodoc:
# Reads a scheduled message ID as a string. `chat.scheduleMessage` returns IDs
# such as `"Q1298393284"`; the `chat.scheduledMessages.list` reference shows an
# integer `id`.
module Slack::Models::Chat::ScheduledMessageIdConverter
  def self.from_json(pull : JSON::PullParser) : String
    pull.kind.int? ? pull.read_int.to_s : pull.read_string
  end

  def self.to_json(value : String, json : JSON::Builder) : Nil
    json.string(value)
  end
end
