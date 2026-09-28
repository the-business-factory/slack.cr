# Run with: crystal run examples/block_kit_markdown.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/markdown_example"

OfflineMarkdownExample.run
