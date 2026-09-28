# Run with: crystal run examples/file_upload.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/file_upload_example"

OfflineFileUploadExample.run
