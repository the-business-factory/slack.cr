# The user viewed something different while the app was visible. The app
# manifest must enable `agent_view` for Slack to send this event.
# https://docs.slack.dev/reference/events/app_context_changed
struct Slack::Events::AppContextChanged < Slack::Event
  getter context : Slack::EventData::AppContext
end
