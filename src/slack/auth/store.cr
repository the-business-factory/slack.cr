require "./clock"
require "./installation"

module Slack::Auth
  enum RefreshPhase
    Acquired
    Dispatched
    Uncertain
  end

  record RefreshLease, credential : CredentialReference, fence : Int64, expires_at : Time
  record RefreshOwnership, lease : RefreshLease, phase : RefreshPhase

  enum RefreshFailure
    Rejected
    UnknownRemoteOutcome
  end

  abstract class InstallationStore
    # Includes tombstones; nil means this key has never existed.
    abstract def fetch(key : InstallationKey) : InstallationRecord?

    # Atomic upsert with exact expected version (nil means insert-only).
    # Active upsert preserves omitted grants; reinstall from tombstone advances generation.
    abstract def store(key : InstallationKey, patch : InstallationPatch, expected : Version?) : InstallationRecord

    # Retain tombstone and advance generation. Duplicate expected version => Conflict.
    abstract def delete(key : InstallationKey, expected : Version) : InstallationRecord

    # Remove only this grant, advancing its revision/fencing all of its refreshes.
    abstract def invalidate(key : InstallationKey, grant : GrantKey, expected : Version) : InstallationRecord

    abstract def acquire(query : InstallationQuery) : CredentialReference

    # Atomic final validity check, immediately before each HTTP dispatch, including retry.
    # Reject deleted/replaced/expired/uncertain grants. Never use cached token on failure.
    abstract def credential_for_dispatch(reference : CredentialReference) : Secret

    # All refresh methods are durable, atomic and cross-process, not process-local locks.
    # Lease duration must be positive; the adapter owns authoritative time.
    abstract def claim_refresh(reference : CredentialReference, lease_duration : Time::Span) : RefreshLease
    abstract def refresh_status(query : InstallationQuery) : RefreshOwnership?

    # Commit before network I/O. Once dispatched, expiry cannot authorize another request.
    abstract def mark_refresh_dispatched(lease : RefreshLease) : Nil

    # Only an unexpired Acquired owner may release (no HTTP request was sent).
    abstract def release_refresh(lease : RefreshLease) : Nil

    # Atomically persist replacement and release ownership; fence + generation + grant
    # revision must still match and phase must be Dispatched with an unexpired lease.
    abstract def complete_refresh(lease : RefreshLease, replacement : Grant) : InstallationRecord

    # Rejected removes grant; unknown quarantines it. Both fence dispatch and retries.
    abstract def fail_refresh(lease : RefreshLease, failure : RefreshFailure) : Nil
  end
end
