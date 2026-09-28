# Run with: crystal run examples/assistant_thread.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/assistant_thread_example"

OfflineAssistantThreadExample.run
