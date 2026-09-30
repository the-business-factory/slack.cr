# Run with: crystal run examples/sign_in.cr
# Signs a person in with Slack offline: synthetic credentials, a recording
# transport, and an ID token that the OpenSSL CLI signed for the tests.
require "./support/sign_in_example"

OfflineSignInExample.run
