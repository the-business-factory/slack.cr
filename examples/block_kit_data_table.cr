# Run with: crystal run examples/block_kit_data_table.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/data_table_example"

OfflineDataTableExample.run
