# Run with: crystal run examples/assistant_events.cr
# Synthetic signed assistant thread and agent session events; no HTTP listener or Slack API calls.
require "./support/assistant_events_example"

OfflineAssistantEventsExample.run
