# An app was installed in an Enterprise organization that this admin app manages.
# `team_id` is the organization ID.
# https://docs.slack.dev/reference/events/app_installed
struct Slack::Events::AppInstalled < Slack::Event
  getter app_id : String
  getter app_name : String
  getter app_owner_id : String?
  getter user_id : String?
  getter team_domain : String?
  getter event_ts : String
end
