# A workspace member's data changed. The user object stays raw JSON.
# https://docs.slack.dev/reference/events/user_change
struct Slack::Events::UserChange < Slack::Event
  getter user : JSON::Any
  getter event_ts : String?
  getter cache_ts : Int64?
end
