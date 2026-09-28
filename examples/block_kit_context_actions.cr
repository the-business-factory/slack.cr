# Run with: crystal run examples/block_kit_context_actions.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/context_actions_example"

OfflineContextActionsExample.run
