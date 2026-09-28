# Run with: crystal run examples/block_kit_overflow.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/overflow_example"

OfflineOverflowExample.run
