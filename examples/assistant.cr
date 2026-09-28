# Run with: crystal run examples/assistant.cr
# Synthetic signed events run through the receiver in memory; Web API calls are recorded, not sent.
require "./support/assistant_example"

OfflineAssistantExample.run
