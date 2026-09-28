# Run with: crystal run examples/app.cr
# Synthetic signed requests run through the receiver in memory; Web API calls are stubbed.
require "./support/app_example"

OfflineAppExample.run
