# Run with: crystal run examples/app_manifest.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/app_manifest_example"

OfflineAppManifestExample.run
