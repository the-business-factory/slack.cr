require "json"

module Slack::Models::Pins
  # A pinned item from `pins.list`: the message or file, the user who pinned
  # it, and when, in Unix seconds.
  struct PinnedItem
    include JSON::Serializable

    getter type : String?
    getter channel : String?
    getter created : Int64?
    getter created_by : String?
    getter message : Slack::Models::Message?
    getter file : Slack::Models::File?
  end
end
