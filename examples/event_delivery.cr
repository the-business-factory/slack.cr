# Run with: crystal run examples/event_delivery.cr
# Synthetic signed retry of an unmapped event; no HTTP listener or Slack API calls.
require "./support/event_delivery_example"

OfflineEventDeliveryExample.run
