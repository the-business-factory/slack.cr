# A workspace member's status changed. The user object stays raw JSON.
# https://docs.slack.dev/reference/events/user_status_changed
struct Slack::Events::UserStatusChanged < Slack::Event
  getter user : JSON::Any
  getter event_ts : String?
  getter cache_ts : Int64?
end
