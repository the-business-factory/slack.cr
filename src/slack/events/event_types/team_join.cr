# A new member joined the workspace. The user object stays raw JSON.
# https://docs.slack.dev/reference/events/team_join
struct Slack::Events::TeamJoin < Slack::Event
  getter user : JSON::Any
end
