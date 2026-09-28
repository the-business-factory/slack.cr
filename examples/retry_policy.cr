# Run with: crystal run examples/retry_policy.cr
# Requests use an injected WebMock transport and synthetic credentials.
# The example really waits Retry-After (2 seconds) before it posts again.
require "./support/retry_policy_example"

OfflineRetryPolicyExample.run
