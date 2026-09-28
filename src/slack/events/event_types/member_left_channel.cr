# A user left a channel that the app is a member of.
# https://docs.slack.dev/reference/events/member_left_channel
struct Slack::Events::MemberLeftChannel < Slack::Event
  getter user : String
  getter channel : String
  getter channel_type : String
  getter team : String?
  getter enterprise : String?
end
