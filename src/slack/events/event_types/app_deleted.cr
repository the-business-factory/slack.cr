# An app was deleted from an Enterprise organization that this admin app manages.
# `team_id` is the organization ID. Requires the `admin.apps:read` scope.
# https://docs.slack.dev/reference/events/app_deleted
struct Slack::Events::AppDeleted < Slack::Event
  getter app_id : String
  getter app_name : String
  getter app_owner_id : String?
  getter team_domain : String?
  getter event_ts : String
end
