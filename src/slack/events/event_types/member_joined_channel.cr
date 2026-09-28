# A user joined a channel that the app is a member of.
#
# `channel_type` is one letter, such as `C` or `G`, and does not identify a
# private channel reliably; use `conversations.info` for that.
# https://docs.slack.dev/reference/events/member_joined_channel
struct Slack::Events::MemberJoinedChannel < Slack::Event
  getter user : String
  getter channel : String
  getter channel_type : String
  getter team : String?
  getter inviter : String?
  getter enterprise : String?
end
