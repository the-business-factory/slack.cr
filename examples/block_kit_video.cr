# Run with: crystal run examples/block_kit_video.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/video_example"

OfflineVideoExample.run
