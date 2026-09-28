# Installation storage test support

`conformance.cr` checks the public `InstallationStore` contract. Supply a factory that makes a fresh store for each example:

```crystal
require "../spec_helper"
require "../support/storage/conformance"

StorageSupport.conformance("my installation adapter",
  ->(clock : StorageSupport::Clock, directory : String) {
    MyInstallationStore.new(clock, directory)
  })
```

The suite supplies an adjustable authoritative clock and a unique temporary directory. It checks exact tenant and grant selection, copied inputs and snapshots, preserving updates, complete versions, tombstones, refresh fencing, invalidation, expiry, and fiber contention. Use your adapter's constructor in the factory. Run storage specs with a cache unique to this invocation, for example:

```sh
CRYSTAL_CACHE_DIR="$(mktemp -d)" crystal spec spec/auth/storage_spec.cr spec/auth/durable_storage_spec.cr
```

Remove only the cache directory created for that run after Crystal exits.

`durable_store.cr` is a test-only local filesystem adapter with synthetic plaintext credentials. A permanent lock file orders transactions; each commit writes and syncs a temporary snapshot, renames it, and syncs the directory. Do not remove its lock file or directory while callers still use it. `snapshot.cr` adds test-only JSON serialization. The process specs race separate writers and refresh owners, kill a process after `Acquired` or durable `Dispatched`, and check restart at the lease deadline. Fault injection distinguishes failure before commit from a lost acknowledgment after commit. WebMock blocks unstubbed requests.

These tests exercise process crashes at controlled barriers, not power loss, filesystem corruption, distributed filesystems, or database isolation. Production adapters need their own concurrency and failure checks. `AuthSupport::ProtocolStore` is a separate sequential model, not a concurrency or durability oracle.
