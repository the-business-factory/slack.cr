# Run with: crystal run examples/event_catalog.cr
# Synthetic signed app events, message subtypes, and a rate-limit notice; no HTTP listener or Slack API calls.
require "./support/event_catalog_example"

OfflineEventCatalogExample.run
