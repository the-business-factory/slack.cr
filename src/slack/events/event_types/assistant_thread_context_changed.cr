# The user viewed a different channel while an assistant thread was open.
# `assistant_thread.context` gives the new context.
# https://docs.slack.dev/reference/events/assistant_thread_context_changed
struct Slack::Events::AssistantThreadContextChanged < Slack::Event
  getter assistant_thread : Slack::EventData::AssistantThread
  getter event_ts : String
end
