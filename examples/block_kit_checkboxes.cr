# Run with: crystal run examples/block_kit_checkboxes.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/checkboxes_example"

OfflineCheckboxesExample.run
