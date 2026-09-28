# The app's user was removed from a user group.
# https://docs.slack.dev/reference/events/subteam_self_removed
struct Slack::Events::SubteamSelfRemoved < Slack::Event
  getter subteam_id : String
end
