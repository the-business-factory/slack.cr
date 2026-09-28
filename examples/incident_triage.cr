# Run with: crystal run examples/incident_triage.cr
# Requests use an injected WebMock transport and synthetic credentials.
require "./support/incident_triage_example"

OfflineIncidentTriageExample.run
