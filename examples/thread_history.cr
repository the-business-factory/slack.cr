# Run with: crystal run examples/thread_history.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/thread_history_example"

OfflineThreadHistoryExample.run
