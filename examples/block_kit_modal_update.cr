# Run with: crystal run examples/block_kit_modal_update.cr
# Synthetic signed submission; no HTTP listener or Slack API calls.
require "./support/modal_update_example"

OfflineModalUpdateExample.run
