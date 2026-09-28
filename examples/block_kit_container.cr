# Run with: crystal run examples/block_kit_container.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/container_example"

OfflineContainerExample.run
