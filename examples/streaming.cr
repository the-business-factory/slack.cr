# Run with: crystal run examples/streaming.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/streaming_example"

OfflineStreamingExample.run
