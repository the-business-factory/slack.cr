# Run with: crystal run examples/block_kit_home.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/home_example"

OfflineHomeExample.run
