# A user requested an app that this admin app manages. The request object
# stays raw JSON.
# https://docs.slack.dev/reference/events/app_requested
struct Slack::Events::AppRequested < Slack::Event
  getter app_request : JSON::Any
end
