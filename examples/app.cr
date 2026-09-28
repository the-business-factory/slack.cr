# Run with: crystal run examples/app.cr
# Synthetic signed requests run through the receiver in memory; Web API and response_url calls are stubbed.
require "./support/app_example"

OfflineAppExample.run
OfflineAppExample.run_replies
OfflineAppExample.run_as_user
