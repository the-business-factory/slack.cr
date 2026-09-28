# A user pinned an item to a channel. The item stays raw JSON.
# https://docs.slack.dev/reference/events/pin_added
struct Slack::Events::PinAdded < Slack::Event
  getter user : String
  getter channel_id : String
  getter item : JSON::Any
  getter event_ts : String
end
