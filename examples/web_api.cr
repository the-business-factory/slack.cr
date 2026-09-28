# Run with: crystal run examples/web_api.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/web_api_example"

OfflineWebApiExample.run
