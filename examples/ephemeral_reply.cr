# Run with: crystal run examples/ephemeral_reply.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/ephemeral_reply_example"

OfflineEphemeralReplyExample.run
