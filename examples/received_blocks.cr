# Run with: crystal run examples/received_blocks.cr
# Synthetic signed click; reads the source message blocks. No HTTP listener or Slack API calls.
require "./support/received_blocks_example"

OfflineReceivedBlocksExample.run
