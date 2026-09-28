# Run with: crystal run examples/block_kit_table.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/table_example"

OfflineTableExample.run
