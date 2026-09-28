# The app's user was added to a user group.
# https://docs.slack.dev/reference/events/subteam_self_added
struct Slack::Events::SubteamSelfAdded < Slack::Event
  getter subteam_id : String
end
