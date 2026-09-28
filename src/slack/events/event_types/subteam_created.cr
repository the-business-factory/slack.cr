# A user group was created. The user group object stays raw JSON.
# https://docs.slack.dev/reference/events/subteam_created
struct Slack::Events::SubteamCreated < Slack::Event
  getter subteam : JSON::Any
end
