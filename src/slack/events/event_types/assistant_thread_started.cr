# A user opened a new assistant thread with the app. `assistant_thread.context`
# gives the channel that the user views, when Slack sends it.
#
# For an app that uses the Agent messages tab, this event does not show that
# the user opened a direct message with the app; use `app_home_opened` with
# the `messages` tab for that.
# https://docs.slack.dev/reference/events/assistant_thread_started
struct Slack::Events::AssistantThreadStarted < Slack::Event
  getter assistant_thread : Slack::EventData::AssistantThread
  getter event_ts : String
end
