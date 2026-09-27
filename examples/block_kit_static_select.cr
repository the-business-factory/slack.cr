# Run with: crystal run examples/block_kit_static_select.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/static_select_example"

OfflineStaticSelectExample.run
