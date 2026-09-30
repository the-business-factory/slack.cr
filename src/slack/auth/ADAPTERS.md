# Public authentication adapter contracts

These obligations apply to applications that implement `Slack::Auth::StateStore`, `InstallationStore`, or `Transport`. Load their public types through `require "slack"`. The in-memory stores are reference implementations for one process; production persistence, access control, encryption at rest, and logging belong to the application.

## State store

`StateStore#issue` must insert a new `AuthorizationAttempt` atomically. A state collision must fail without replacing the first attempt. `consume` must check state, trusted session binding, purpose, and expiry, then delete the matching attempt in one atomic operation. A mismatch must not delete a valid attempt. Invalid state raises `ContractError` with `InvalidState`. State expires at `expires_at <= now`. The installation handler creates random state and spends valid state before it checks callback denial or code. It never restores state after token exchange failure.

Use an authoritative time source shared by processes that handle install start and callback. `MemoryStateStore` is only a single-process adapter. It prunes expired noncolliding entries on issue and exposes `prune_expired` for scheduled cleanup; it starts no fiber.

## Identity and snapshot ownership

`InstallationKey` contains the exact app ID, kind, enterprise ID, and team ID. A workspace key requires a team; an organization key requires an enterprise and no team. Never search another tenant when an exact key is missing. Actor and visible team are request metadata, not owner identity. `GrantKey` selects a bot or one explicit user ID. User-map keys must match their grant subject IDs; a bot grant subject is its authenticated user ID.

`InstallationPatch` replaces only supplied bot, user, and webhook values. Omitted values remain on an active update. Explicit invalidation removes a grant. Copy caller collections and returned snapshots so callers cannot mutate stored state through aliases. Protect access tokens, refresh tokens, and webhook bearer URLs; `Secret` redacts display but does not encrypt or erase memory.

## Atomic record operations

Every store operation must be durable and have one consistent transaction order across processes. A local mutex alone is insufficient. Use authoritative transaction time for expiry, refresh leases, and dispatch; client clocks with unknown skew cannot establish one order.

| Operation | Required behavior |
| --- | --- |
| `fetch` | Return the active record, retained tombstone, or `nil` only if the key never existed. |
| `store(key, patch, nil)` | Insert only if no active record or tombstone exists. |
| `store(key, patch, expected)` | Compare the **complete** generation and revision. On active update, advance record revision, replace only supplied grants, advance their revisions, and cancel their refresh ownership. On tombstone reinstall, advance generation and do not restore deleted grants. |
| `invalidate` | Compare complete version, remove only the selected grant, invalidate its refresh ownership, and preserve other grants' revisions. |
| `delete` | Compare complete version, remove every credential, webhook, and refresh owner; keep a tombstone with advanced generation and revision. |

Record revisions never decrease or repeat across deletion and reinstall. Replacement grant revisions never repeat for that installation. Reject counter overflow and retain enough history to prevent old generations or revisions from becoming valid again. Missing data, stale versions, and storage errors raise `ContractError`; they cannot select a fallback tenant or report a successful mutation. An atomic failure leaves previous state intact. If acknowledgment is lost, inspect the committed version and ownership before deciding what happened.

`acquire` returns a versioned `CredentialReference`. `credential_for_dispatch` must atomically check generation, grant revision, existence, expiry, and refresh ownership immediately before each HTTP send, including a permitted retry. `Dispatched` gives `RefreshBusy`; `Uncertain` gives `UnknownRemoteOutcome`. Never use a cached token after this check fails. Revocation before the check prevents a send; revocation after the check cannot recall an admitted send. Do not queue work or run callbacks between this check and transport dispatch.

## Refresh leases and uncertainty

Coordinate by complete installation key and `GrantKey`, including the user ID. A lease has generation, grant revision, increasing fence, and deadline. Every transition checks its exact lease and credential version in one transaction.

1. `claim_refresh` requires a valid reference, positive duration, and refresh token. It atomically establishes `Acquired` ownership; contention returns `RefreshBusy`.
2. `mark_refresh_dispatched` must durably commit the unexpired current lease **before** HTTP. If its acknowledgment is lost, read ownership before sending. An unreadable result sends nothing.
3. `complete_refresh` accepts only the current, unexpired `Dispatched` lease and matching subject. It saves the replacement and clears ownership atomically. Unrelated grant updates must survive and must not prevent completion solely because the record revision advanced.
4. `fail_refresh(Rejected)` removes the selected grant; `UnknownRemoteOutcome` quarantines it as `Uncertain`. Neither permits a blind HTTP retry. `release_refresh` is allowed only for an unexpired `Acquired` lease that sent no request.

When `Acquired` expires, a new owner may claim with a new fence. When `Dispatched` expires, it becomes `Uncertain`; do not reuse the refresh token. `refresh_status` applies these expiry transitions atomically before returning. Uncertain ownership persists until new authorization, targeted invalidation, or uninstall/reinstall. A late completion after lease expiry must fail, even with a successful response.

A successful remote exchange followed by local persistence failure yields `RotationPersistenceError#pending`. Retry **only local completion** while the original lease remains valid. If completion may have committed, `RotationService#recover` accepts it only when the generation matches, grant revision increased, and the **entire stored replacement grant equals the pending replacement**. Revision increase by itself can represent another writer. A changed generation, revoked grant, invalid lease, or mismatched replacement must not restore old credentials. Applications must protect a pending replacement retained for recovery; the library provides no durable serialization format.

Revocation and refresh completion follow their atomic order. Revocation first invalidates the lease. Completion first advances the grant revision; cleanup prepared for an older grant must conflict. Reinstall changes generation, so an old lease cannot restore credentials. The lifecycle service keeps the generation and grant revisions captured during preparation when retrying conflicts. Applications own event deduplication and delivery history; the service cannot infer a delayed event's original generation from its arrival time.

## Transport and errors

`Transport#execute` sends one request and returns status, headers, and body. It does not retry or redirect. Classify only a definitely unsent application request as `TransportFailure`; any partial write or failure after bytes may have left is `UnknownRemoteOutcome`. `TransportFactory#build` validates timeout, proxy, CA, TLS, and endpoint settings. Keep API, OAuth, and OIDC configuration separate. Endpoint configuration does not verify identity.

`ContractError` carries an allowed error code, optional HTTP status, and retry delay. Do not include remote bodies, raw exceptions, headers, URIs, or tokens in errors or logs. Parse String or IO responses once. `Secret#value` exposes its contents for dispatch or storage; `inspect` and `to_s` redaction do not protect explicit accessors or serialization.

## Validation

Run the [storage conformance suite](../../../spec/support/storage/README.md) against a fresh instance and add process contention, restart, crash, and lost-acknowledgment tests for the production adapter. The repository's durable filesystem adapter is test support for synthetic secrets, not a production database or a portable storage format.
