# Authentication contracts

These interfaces define how authentication services share state, credentials, and HTTP access. Require the contract entry point directly:

```crystal
require "./src/slack/auth/contracts"

clock : Slack::Auth::Clock = Slack::Auth::SystemClock.new
key : Slack::Auth::InstallationKey = Slack::Auth::InstallationKey.new(
  "A1", :workspace, team_id: "T1"
)
query : Slack::Auth::InstallationQuery = Slack::Auth::InstallationQuery.new(
  key, Slack::Auth::GrantKey.new(:bot)
)
```

Run this example from the repository root. It creates a query, not an authenticated request. Applications can still supply tokens directly to the existing API client.

Concrete storage adapters, HTTP clients, and authentication services are separate work. These contracts do not enable Sign in with Slack.

## Time and authorization state

Inject a `Clock`; `SystemClock#now` returns UTC. Each store must use an authoritative clock for expiry, leases, and credential checks. Across processes, use database transaction time or an equivalent shared clock. Do not rely on client clocks with unknown differences.

State and credentials expire when `expires_at <= now`. The rotation service sets the refresh margin. It can acquire a reference to an expired grant, but it cannot use that grant for an API request.

An `AuthorizationAttempt` contains state, session binding, purpose, expiry, redirect URI, and an optional OIDC nonce.

- The installation service generates cryptographically random state.
- The application supplies trusted session binding. Do not read it from callback parameters.
- The server controls the redirect URI.
- OIDC attempts require a separate random nonce. Installation attempts reject a nonce.
- A session can have several active attempts, such as separate browser tabs.

The constructor stores data. It does not generate state or verify a callback.

`StateStore#issue` inserts a new attempt. A collision must fail without replacing the existing attempt. `consume` checks state, session, purpose, and expiry, then deletes the matching attempt in one atomic operation. Invalid input raises `ContractError` with code `InvalidState`. A mismatch must not delete a valid attempt.

For an application that already has a configured `state_store` and trusted inputs:

```crystal
attempt : Slack::Auth::AuthorizationAttempt = state_store.consume(
  returned_state, session_binding, Slack::Auth::AuthorizationPurpose::Installation
)
# Exchange the callback code only after consume succeeds.
```

The state remains consumed if code exchange fails. Start a new authorization attempt; do not reuse the callback code.

## Installation and grant identity

An `InstallationKey` contains the exact app, installation kind, enterprise, and team IDs. Empty IDs are invalid.

| Installation kind | Required ID | Other ID rules |
| --- | --- | --- |
| Workspace | Team | Enterprise can be absent. |
| Organization | Enterprise | Team must be absent. |

Resolve one trusted installation owner before creating an `InstallationQuery`. There is no wildcard lookup or fallback to another installation. Keep the actor user and visible team as separate metadata. A visible workspace is not part of an organization installation key.

A `GrantKey` selects a bot grant or one explicit user ID:

```crystal
bot_key : Slack::Auth::GrantKey = Slack::Auth::GrantKey.new(:bot)
user_key : Slack::Auth::GrantKey = Slack::Auth::GrantKey.new(:user, "U1")
```

App-level tokens and app-configuration tokens are outside this model.

A `Grant` contains the subject ID, access token, scopes, optional refresh token, and absolute expiry. A bot grant uses the bot's authenticated user ID as its subject. The authorization service can obtain additional identity data through `auth.test`. Each user-map key must match its grant's subject ID.

Bot and user grants have separate lifecycles. `IncomingWebhook` contains its bearer URL, channel ID, and optional configuration URL. Parsing and validation of Slack responses remain separate responsibilities.

`InstallationPatch` replaces only the supplied bot, users, and webhook values. Omitted values preserve existing data. Use explicit invalidation to remove credentials. Snapshot collections are copied so callers cannot change stored data through a returned value.

## Store versions and deletion

Every `InstallationStore` operation must be atomic and durable across processes. Operations must have one consistent order visible to all callers.

A `Version` identifies the record revision and installation generation. A generation identifies one installation lifecycle. A tombstone is the retained record of a deleted installation.

| Operation | Required behavior |
| --- | --- |
| `fetch` | Return an active snapshot, a tombstone, or `nil` if the key never existed. |
| `store` | Compare the complete expected version. With `nil`, insert only if no record or tombstone exists. |
| Active update | Increase the record revision. Replace only supplied grants, increase their revisions, and cancel their refresh ownership. |
| Reinstall | Compare the tombstone version and increase the generation. Do not restore deleted grants. |
| `invalidate` | Compare the record version. Remove only the selected grant and invalidate its refresh ownership. Preserve other grant revisions. |
| `delete` | Compare the version. Remove all credentials, webhook data, and refresh ownership. Retain a tombstone with increased generation and revision. |

Record revisions increase across deletion and reinstall. Each replacement grant receives a revision that was never used for that installation. Generations must never repeat. Reject counter overflow. Do not remove stored history if that can allow an old generation to be reused.

Missing data, stale versions, and storage errors raise `ContractError`. They must not select another tenant or return a successful mutation. An atomic storage failure leaves the previous state intact. If the commit result is lost, read the stored version and ownership to determine what happened. Do not assume rollback.

Duplicate or delayed revocation events need the expected version or generation for the affected installation. The store cannot infer an event's original generation from its arrival time. The lifecycle service must handle event order and duplicates. It must not fetch a new reinstall version just to apply an old revocation. If an event cannot identify the intended generation, the service needs an explicit conservative policy.

## Refresh ownership

Coordinate refresh by installation and `GrantKey`, including the user ID. A lease contains the installation generation, grant revision, increasing fence value, and deadline. The fence lets the store reject an old owner after ownership changes.

A lease is not a secret and does not authorize access to another tenant. Every transition checks the complete lease and credential version in one transaction. A mutex in one process does not satisfy this requirement across processes.

1. Call `acquire(query)` for a credential reference.
2. Call `claim_refresh(reference, duration)` with a positive duration. The store checks the generation, grant revision, and refresh token. It assigns `Acquired` ownership atomically. Other callers receive `RefreshBusy`.
3. Persist `mark_refresh_dispatched(lease)` before sending HTTP. Only the current, unexpired `Acquired` owner can do this. If the storage result is uncertain, determine the stored state before sending. The transport sends one request without automatic retries or redirects.
4. On success, call `complete_refresh(lease, replacement)`. The subject must remain the same. The store accepts only the current, unexpired `Dispatched` owner. It saves the replacement and clears ownership atomically. Changes to other grants must survive and must not prevent completion solely because the record revision changed.
5. On definite rejection, call `fail_refresh(lease, Rejected)`. This removes the grant. On an uncertain remote result, use `UnknownRemoteOutcome`. This keeps `Uncertain` ownership and blocks use of the grant. Neither result permits a blind refresh retry.

An unexpired `Acquired` owner can call `release_refresh` only if it sent no request.

| Expired ownership | Recovery |
| --- | --- |
| `Acquired` | Assign a new owner with a new fence. The required pre-send transition did not occur. |
| `Dispatched` | Change to `Uncertain`. Do not send the old refresh token again. |

A crash after marking `Dispatched` but before sending also blocks the grant. This can require a new authorization, but prevents use of a one-time refresh token twice.

## Uncertain results and revocation races

`refresh_status` applies expiry changes atomically before returning ownership. `Uncertain` ownership does not clear automatically. A new authorization, targeted invalidation, or uninstall/reinstall can replace it. There is no operation to retry the old token manually.

Reject late completion after lease expiry, even when it includes a successful remote response.

A successful response followed by a storage failure produces `PersistenceFailure`. Keep replacement credentials secure and read the stored state. Retry only local persistence while the original fence and lease remain valid. After expiry or uncertain ownership, require new authorization. If completion committed but its acknowledgment was lost, the increased grant revision can show that result. Never repeat the remote refresh request to recover a storage result.

Revocation and refresh completion follow their atomic transaction order:

- If revocation occurs first, it removes the grant and invalidates the lease. Old refresh completion fails.
- If completion occurs first, it increases the revision. An old revocation version conflicts. The lifecycle service must check the event's intended generation.
- Reinstall changes the generation. A previous refresh cannot restore old credentials.

## Credential checks before HTTP requests

Request contexts retain `CredentialReference`, not a token they can reuse indefinitely. Immediately before each HTTP send, including an allowed retry, call `credential_for_dispatch`.

For an application with a configured `store` and `query`:

```crystal
reference : Slack::Auth::CredentialReference = store.acquire(query)
token : Slack::Auth::Secret = store.credential_for_dispatch(reference)
# Use token.value for the immediate HTTP send. Do not log it.
```

The check verifies generation, grant revision, existence, expiry, and refresh state. `Dispatched` refresh blocks the call with `RefreshBusy`. `Uncertain` ownership blocks it with `UnknownRemoteOutcome`. Do not use a cached token if the check fails.

This atomic check determines whether a request can proceed. A revocation completed before the check prevents the send. A revocation after the check cannot recall an admitted request. Do not put queued work, waits, refreshes, or user callbacks between the check and send. A queued job must acquire and check credentials when it sends.

Storage and Slack HTTP cannot form one atomic transaction. Callers that supply tokens directly remain responsible for their token lifecycle.

## Transport and safe errors

`Transport#execute` takes a method, URI, headers, and body. It returns status, headers, and body once. Use `TransportFailure` only when the request was definitely not sent. Use `UnknownRemoteOutcome` when it might have been sent.

`TransportFactory#build` accepts connect, read, and write timeouts, proxy settings, and CA configuration. Concrete implementations must validate these settings, TLS policy, and endpoint URLs. Contracts do not read global environment variables.

API, OAuth authorization/token/redirect, and future OIDC discovery/issuer settings are separate. Future OIDC must obtain keys from validated discovery. Endpoint configuration alone does not verify identity.

`ContractError` contains an allowed error code, optional HTTP status, and retry delay. It must not contain remote bodies, raw exception causes, headers, or tokens. Response handlers must map allowed remote codes to typed failures and parse String or IO input only once. Do not copy arbitrary remote text into diagnostics.

`Secret` hides its value in `inspect` and `to_s`. Use `.value` explicitly to send or store it. Transport diagnostics hide bodies, headers, and URIs. Do not log configuration or URI objects. Secret wrappers do not encrypt data or erase memory.

## Adapter validation

Applications own production storage, encryption at rest, access controls, and safe logging.

`AuthSupport::ProtocolStore` is a sequential test model. Its hash maps do not implement concurrent or durable storage. Its tests cover method usage and operation order, not production guarantees.

A durable test adapter must verify transactions, atomic state consumption, version checks, grant isolation, lease recovery, storage failures, stale-owner rejection, restart, and contention between separate processes. Use deterministic synchronization and bounded waits.

The contract tests use synthetic data and make no live requests. They do not prove durable rollback, recovery from lost acknowledgments, cross-process coordination, endpoint validation, or complete authentication flows. OIDC verification and existing-token migration remain deferred.
