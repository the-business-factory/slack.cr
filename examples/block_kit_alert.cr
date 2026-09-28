# Run with: crystal run examples/block_kit_alert.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/alert_example"

OfflineAlertExample.run
