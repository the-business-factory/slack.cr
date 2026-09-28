# Run with: crystal run examples/block_kit_modal_push.cr
# Synthetic signed submission; no HTTP listener or Slack API calls.
require "./support/modal_push_example"

OfflineModalPushExample.run
