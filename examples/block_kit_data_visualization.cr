# Run with: crystal run examples/block_kit_data_visualization.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/data_visualization_example"

OfflineDataVisualizationExample.run
