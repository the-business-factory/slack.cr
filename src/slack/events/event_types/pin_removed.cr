# A user removed a pinned item from a channel. The item stays raw JSON.
# https://docs.slack.dev/reference/events/pin_removed
struct Slack::Events::PinRemoved < Slack::Event
  getter user : String
  getter channel_id : String
  getter item : JSON::Any
  getter event_ts : String

  # False when the channel has no pinned items left.
  getter? has_pins : Bool?
end
