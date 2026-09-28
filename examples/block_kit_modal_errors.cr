# Run with: crystal run examples/block_kit_modal_errors.cr
# Synthetic signed submissions; no HTTP listener or Slack API calls.
require "./support/modal_errors_example"

OfflineModalErrorsExample.run
