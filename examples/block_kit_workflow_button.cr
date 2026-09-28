# Run with: crystal run examples/block_kit_workflow_button.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/workflow_button_example"

OfflineWorkflowButtonExample.run
