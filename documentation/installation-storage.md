# Installation storage adapters

Require the reference adapter directly. It implements the [authentication contracts](auth-contracts.md) without changing their interfaces:

```crystal
require "./src/slack/auth/storage/memory_installation_store"

store : Slack::Auth::InstallationStore = Slack::Auth::MemoryInstallationStore.new
key = Slack::Auth::InstallationKey.new("A1", :workspace, team_id: "T1")
grant = Slack::Auth::Grant.new("B1", Slack::Auth::Secret.new("synthetic-token"), ["chat:write"])
record = store.store(key, Slack::Auth::InstallationPatch.new(bot: grant), nil)

# Use the complete version for an update. Omitted grants remain unchanged.
updated = store.store(key, Slack::Auth::InstallationPatch.new(
  users: {"U1" => Slack::Auth::Grant.new("U1", Slack::Auth::Secret.new("synthetic-user-token"), ["search:read"])}
), record.version)
query = Slack::Auth::InstallationQuery.new(key, Slack::Auth::GrantKey.new(:user, "U1"))
reference = store.acquire(query)
token = store.credential_for_dispatch(reference)
# Send immediately with token.value. Do not log or cache the token.
```

Run examples from the repository root. Use normalized, validated grants from the authorization service. This adapter does not parse Slack wire responses. Response normalization integration remains separate.

## Reference adapter limits

`MemoryInstallationStore` orders whole operations with one mutex. Fibers share this instance; the adapter starts no background fibers. Snapshots copy their collections. Grant updates, invalidation, and refresh completion use the same lock.

Data survives only while this object exists. Each instance has independent data. This reference adapter does not provide the cross-process durability required for a deployed installation store. `Storage::Engine` is internal transaction state; use the adapter, not the engine directly.

A deleted installation retains a tombstone. Reinstall requires the tombstone version and creates a new generation. Record revisions, generations, and refresh fences cannot wrap. Replacement grants use the new record revision. Unrelated grants keep their revisions and refresh ownership.

## Reuse the conformance tests

Add a spec that loads the project spec helper and the suite. Supply a factory with a fresh store for each example:

```crystal
require "../spec_helper"
require "../support/storage/conformance"

StorageSupport.conformance("my installation adapter",
  ->(clock : StorageSupport::Clock, directory : String) {
    Slack::Auth::MemoryInstallationStore.new(clock)
  })
```

Replace the factory body with the adapter under test. The suite supplies an adjustable authoritative clock and a unique temporary directory. It checks the complete tenant key and dispatches distinct bot and user credentials before and after grant changes. Actor and visible-team metadata must not change credential selection. It also checks copied patch inputs and snapshots, preserving updates, versions, deletion, refresh fencing, invalidation, and expiry through a second refresh cycle. The fiber contention test releases two ready fibers through a barrier, waits for both results with a deadline, then closes all channels.

The conformance suite does not load JSON serialization. The durable tests load `snapshot.cr`, which adds serialization only for the types in a test snapshot. The earlier `AuthSupport::ProtocolStore` is a separate sequential model for contract examples. It does not share the engine, but its similar transition logic is not an independent correctness oracle and does not prove concurrency.

Run all storage tests with a cache path unique to the worktree:

```sh
CRYSTAL_CACHE_DIR=/tmp/slack-installation-store-cache crystal spec spec/auth/storage_spec.cr spec/auth/durable_storage_spec.cr
```

## Durable test adapter

`spec/support/storage/durable_store.cr` is a test adapter for synthetic credentials on a local filesystem. It is not a production database adapter. Test-only JSON serialization is loaded with this support file; it does not define a public storage or wire format.

Each transaction takes an exclusive lock on a permanent lock file, loads the committed snapshot, applies one operation, writes and syncs a temporary snapshot, renames it, and syncs the directory. Do not remove the lock file or directory while any caller uses the store. Nonblocking lock attempts yield to other fibers and stop after five seconds. The process tests use a shared clock file. Default test use can use the host UTC clock; this does not establish a clock authority across hosts.

The separate-process tests release competing processes through file barriers. They check that only one refresh claim or competing CAS update succeeds. They also race refresh completion against targeted invalidation and deletion using the same original version. Each race must produce one valid transaction order; a fresh adapter checks the stored result, unrelated grants, and dispatch with stale references. The tests use bounded readiness and completion waits.

The crash tests kill an owner after `Acquired` and after durable `Dispatched`, restart the adapter, and check recovery at the exact lease deadline. An expired acquired lease permits a new fence. An expired dispatched lease becomes uncertain and cannot reuse the refresh token. The probe requires WebMock to block unstubbed HTTP requests; no Slack call is needed.

Fault injection distinguishes failure before commit from a lost acknowledgment after commit. Read the stored ownership after an uncertain dispatch write. After a completion persistence failure, retain the replacement securely and reconcile the grant revision and ownership. Retry only local persistence while the original lease is valid. Never repeat refresh HTTP to recover a storage result. A newer revision proves that the old reference is stale; it does not by itself identify which competing authorization wrote the new grant.

These tests cover process crashes at protocol barriers, not power loss, filesystem corruption recovery, distributed filesystems, or database isolation. The test snapshots contain plaintext secrets and must contain synthetic values only.

## Application responsibilities

Applications own production storage, encryption at rest, access controls, backup policy, authoritative transaction time, and safe logging. A production adapter must implement the same atomic transitions across processes and pass its own failure and concurrency tests. Keep tombstones and monotonic counters so delayed work cannot restore a previous installation.

State storage is a separate contract. Request authorization, response normalization, and live install/refresh/revocation checks remain integration work. Existing callers that pass tokens directly retain responsibility for token lifecycle.
