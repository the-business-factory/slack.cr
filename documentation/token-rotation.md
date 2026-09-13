# Token rotation

Require `slack/auth/rotation_service` explicitly. Rotation uses the existing
installation store and OAuth response parser. Applications schedule rotation;
the service starts no background fibers.

```crystal
require "./src/slack/auth/rotation_service"
require "./src/slack/auth/http_transport_factory"

def rotation_service(store : Slack::Auth::InstallationStore,
                     configuration : Slack::Auth::OAuthConfiguration) : Slack::Auth::RotationService
  transport = Slack::Auth::HTTPTransportFactory.new.build(Slack::Auth::TransportOptions.new)
  client = Slack::Auth::RefreshClient.new(configuration, transport)
  Slack::Auth::RotationService.new(store, client,
    policy: Slack::Auth::RotationPolicy.new(refresh_margin: 5.minutes, lease_duration: 2.minutes))
end
```

Run this example from the repository root. Supply your validated OAuth
configuration and a durable installation adapter. The memory adapter is for
local use only. See [installation storage](installation-storage.md).

## Select and rotate a grant

Call `service.rotate(query)` for one trusted `InstallationQuery`. It returns a
`CredentialReference`, not an access token. Bot grants and each user's grant
rotate independently. Actor and visible-team metadata do not change the owner.
The service does not search for another grant or tenant.

Rotation is due when `expires_at - clock.now <= refresh_margin`. The default
margin is five minutes. The margin can be zero through one hour, inclusive.
Choose it to cover expected clock skew and scheduling delay. The store must
still use an authoritative clock for leases and dispatch checks.

A fresh grant causes no refresh HTTP. A grant without expiry stays unchanged.
A due grant without a refresh token raises `ReauthorizationRequired`. This
service does not migrate long-lived tokens.

Each call sends at most one HTTP request. Contention raises `RefreshBusy`
immediately. There is no wait, automatic HTTP retry, or retry scheduler. Lease
duration defaults to two minutes and must be greater than zero and at most ten
minutes. Set transport timeouts below that duration, allowing time for storage.
Expiry for the replacement uses the clock at the start of the exchange plus
Slack's `expires_in`; response delay cannot extend its recorded lifetime.

Call rotation before creating a new request context or entering a dispatch
wait. Existing contexts retain their original credential reference. Always
call `credential_for_dispatch(reference)` immediately before sending the API
request. Do not refresh, wait, or run callbacks between that check and the send.
The read-only `service.store` getter allows integration code to check that the
authorizer and rotation service share the same adapter instance.

## Failure and recovery

| Result | Required action |
| --- | --- |
| `RefreshBusy` | Another owner is active. Defer the operation and acquire again later. |
| `ReauthorizationRequired` | Obtain new authorization. A definite refresh-token rejection removes only the selected grant. |
| `UnknownRemoteOutcome` | Do not resend the old refresh token. Obtain new authorization. |
| `TransportFailure` | No request bytes were sent, but durable `Dispatched` ownership already exists. The current store protocol quarantines this grant; obtain new authorization. |
| `RotationPersistenceError` | Retain its `pending` value securely and retry local persistence only. |
| Other `PersistenceFailure` | No successful replacement is available to this call. Resolve storage health and stored ownership; do not assume rollback. |
| `Conflict` | A version, fence, or lease changed. Do not restore the old grant. |

Malformed responses, redirects, server errors, rate limits, wrong grant types,
and unclassified transport exceptions are uncertain outcomes. Safe HTTP status
and retry-delay metadata can be reported, but it does not permit refresh retry.
The service removes a grant only for an allowlisted refresh rejection in a
successful HTTP response or HTTP 400, 401, or 403 response.

The service persists `Dispatched` before HTTP. If this write loses its
acknowledgment, it reads ownership before sending. Only the exact confirmed
`Dispatched` lease permits the request. If the write rolled back to `Acquired`,
the service releases that lease and sends nothing. An unreadable result sends
nothing. If a quarantine write fails, `Dispatched` still blocks the grant and
becomes `Uncertain` at expiry.

Handle a successful exchange followed by a failed save separately:

```crystal
def rotate_with_local_recovery(service : Slack::Auth::RotationService,
                               query : Slack::Auth::InstallationQuery) : Slack::Auth::CredentialReference
  service.rotate(query)
rescue error : Slack::Auth::RotationPersistenceError
  # This is one bounded local retry. It never sends refresh HTTP.
  service.recover(error.pending)
end
```

If recovery also fails, retain `pending` securely under application policy.
It contains the lease and replacement credentials. Recovery can use a new
service and adapter instance for the same store. Applications own secure
persistence of this value if recovery must survive a process restart; the
library defines no serialization format for it. Losing this value after a
successful remote exchange can require new authorization.

`recover` accepts an already saved replacement only when the installation
generation matches, the grant revision increased, and every grant field equals
the retained replacement. A newer revision alone is insufficient. Otherwise,
local completion must still pass the original store lease and fence checks.
Lease expiry, replacement, revocation, and reinstall prevent stale completion.

## Protocol and validation

`RefreshClient` sends one form-encoded POST to the configured HTTPS token URI,
with `grant_type=refresh_token` and the refresh token. Client credentials use
HTTP Basic authentication. The endpoint cannot contain a query, fragment, or
user information. The client snapshots its configuration and uses only the
token endpoint and client credentials; authorization and redirect settings are
not used for refresh. See Slack's [oauth.v2.access reference](https://docs.slack.dev/reference/methods/oauth.v2.access/).

Slack documents bot and user refresh grants and instructs applications to keep
the replacement refresh token. Refresh tokens are intended for one use. This
service does not rely on Slack's grace period. See [Slack token rotation](https://docs.slack.dev/authentication/using-token-rotation/).
These wire assumptions were checked on 2026-09-12.

All rotation tests use synthetic credentials and offline transports. They reuse
the [OAuth fixtures and provenance](../spec/fixtures/oauth_responses/provenance.yml).
The durable test adapter verifies local recovery and process coordination;
it is not a production database adapter. Tests kill a process during its fake
exchange and verify that a new process cannot resend its refresh token.

Live Slack refresh, real rejection, GovSlack, production database failures, and
consumer application integration remain pending. Offline success does not
establish live validation.
