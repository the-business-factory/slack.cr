# Run with: crystal run examples/custom_step.cr
# Synthetic signed requests run through the receiver in memory; Web API calls are stubbed.
require "./support/custom_step_example"

OfflineCustomStepExample.run
