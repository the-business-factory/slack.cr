# Run with: crystal run examples/attachments.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/attachments_example"

OfflineAttachmentsExample.run
