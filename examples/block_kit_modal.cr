# Run with: crystal run examples/block_kit_modal.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/modal_example"

OfflineModalExample.run
