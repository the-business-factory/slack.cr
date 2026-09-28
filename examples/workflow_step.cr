# Run with: crystal run examples/workflow_step.cr
# Synthetic function_executed events; requests use an injected WebMock transport.
require "./support/workflow_step_example"

OfflineWorkflowStepExample.run
