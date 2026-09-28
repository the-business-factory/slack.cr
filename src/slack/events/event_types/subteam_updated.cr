# A user group changed. The user group object stays raw JSON.
# https://docs.slack.dev/reference/events/subteam_updated
struct Slack::Events::SubteamUpdated < Slack::Event
  getter subteam : JSON::Any
end
