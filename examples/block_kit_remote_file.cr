# Run with: crystal run examples/block_kit_remote_file.cr
# Adds and shares a remote file, then prints the unfurls value for it.
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/remote_file_example"

OfflineRemoteFileExample.run
