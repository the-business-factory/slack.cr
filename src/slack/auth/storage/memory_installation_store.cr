require "./engine"

module Slack::Auth
  # Single-process reference adapter. Data is lost when this object is discarded.
  # One mutex orders complete operations across fibers; no background fibers exist.
  class MemoryInstallationStore < InstallationStore
    @mutex = Mutex.new
    @engine : Storage::Engine

    def initialize(@clock : Clock = SystemClock.new)
      @engine = Storage::Engine.new(@clock)
    end

    def fetch(key : InstallationKey) : InstallationRecord?
      transaction(&.fetch(key))
    end

    def store(key : InstallationKey, patch : InstallationPatch, expected : Version?) : InstallationRecord
      transaction(&.store(key, patch, expected))
    end

    def delete(key : InstallationKey, expected : Version) : InstallationRecord
      transaction(&.delete(key, expected))
    end

    def invalidate(key : InstallationKey, grant : GrantKey, expected : Version) : InstallationRecord
      transaction(&.invalidate(key, grant, expected))
    end

    def acquire(query : InstallationQuery) : CredentialReference
      transaction(&.acquire(query))
    end

    def credential_for_dispatch(reference : CredentialReference) : Secret
      transaction(&.credential_for_dispatch(reference))
    end

    def claim_refresh(reference : CredentialReference, lease_duration : Time::Span) : RefreshLease
      transaction { |engine| engine.claim_refresh(reference, lease_duration) }
    end

    def refresh_status(query : InstallationQuery) : RefreshOwnership?
      transaction(&.refresh_status(query))
    end

    def mark_refresh_dispatched(lease : RefreshLease) : Nil
      transaction(&.mark_refresh_dispatched(lease))
    end

    def release_refresh(lease : RefreshLease) : Nil
      transaction(&.release_refresh(lease))
    end

    def complete_refresh(lease : RefreshLease, replacement : Grant) : InstallationRecord
      transaction { |engine| engine.complete_refresh(lease, replacement) }
    end

    def fail_refresh(lease : RefreshLease, failure : RefreshFailure) : Nil
      transaction(&.fail_refresh(lease, failure))
    end

    protected def transaction(& : Storage::Engine -> T) : T forall T
      @mutex.synchronize { yield @engine }
    end
  end
end
