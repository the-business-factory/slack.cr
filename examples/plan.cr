# Run with: crystal run examples/plan.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/plan_example"

OfflinePlanExample.run
