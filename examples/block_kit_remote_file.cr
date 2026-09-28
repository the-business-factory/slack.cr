# Run with: crystal run examples/block_kit_remote_file.cr
# Prints the unfurls value for a remote file. It sends no Slack request.
require "./support/remote_file_example"

OfflineRemoteFileExample.run
