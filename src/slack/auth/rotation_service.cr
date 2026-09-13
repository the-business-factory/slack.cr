require "./refresh_client"
require "./rotation_policy"
require "./rotation_persistence_error"

module Slack::Auth
  # No background fibers: applications schedule calls. The store coordinates owners
  # across fibers/processes; each call performs at most one remote exchange.
  class RotationService
    getter store : InstallationStore

    def initialize(@store : InstallationStore, @client : RefreshClient, *,
                   @clock : Clock = SystemClock.new, @policy : RotationPolicy = RotationPolicy.new)
    end

    def rotate(query : InstallationQuery) : CredentialReference
      reference = @store.acquire(query)
      previous = checked_grant(reference)
      check_ownership(query)
      expires_at = previous.expires_at
      return reference unless expires_at && @policy.due?(expires_at, @clock.now)
      refresh_token = previous.refresh_token || raise ContractError.new(:reauthorization_required)
      lease = @store.claim_refresh(reference, @policy.lease_duration)
      mark_dispatched(lease)
      replacement = exchange(lease, previous, refresh_token)
      persist(PendingRotation.new(lease, replacement))
    end

    # Recovery never calls Slack. It accepts a lost acknowledgment only when the
    # same generation contains the exact replacement, not merely a newer revision.
    def recover(pending : PendingRotation) : CredentialReference
      original = pending.lease.credential
      current = @store.acquire(original.query)
      if current != original
        grant = checked_grant(current)
        unless current.generation == original.generation &&
               current.grant_revision > original.grant_revision && grant == pending.replacement
          raise ContractError.new(:conflict)
        end
        check_ownership(original.query)
        return current
      end
      persist(pending)
    rescue error : ContractError
      raise RotationPersistenceError.new(pending) if error.code.persistence_failure?
      raise error
    end

    private def checked_grant(reference : CredentialReference) : Grant
      record = @store.fetch(reference.query.owner)
      raise ContractError.new(:missing_installation) if !record || record.deleted?
      stored = record.grant(reference.query.grant)
      unless stored && record.version.generation == reference.generation && stored.revision == reference.grant_revision
        raise ContractError.new(:conflict)
      end
      stored.grant
    end

    private def check_ownership(query : InstallationQuery) : Nil
      if ownership = @store.refresh_status(query)
        raise ContractError.new(ownership.phase.uncertain? ? ErrorCode::UnknownRemoteOutcome : ErrorCode::RefreshBusy)
      end
    end

    private def mark_dispatched(lease : RefreshLease) : Nil
      @store.mark_refresh_dispatched(lease)
    rescue error : ContractError
      raise error unless error.code.persistence_failure?
      # Resolve a lost write acknowledgment before sending. A failed read sends
      # nothing; an Acquired lease can safely be released because no HTTP ran.
      ownership = @store.refresh_status(lease.credential.query)
      raise error unless ownership && ownership.lease == lease
      return if ownership.phase.dispatched?
      @store.release_refresh(lease) if ownership.phase.acquired?
      raise error
    end

    private def exchange(lease : RefreshLease, previous : Grant, refresh_token : Secret) : Grant
      # Start-time expiry is conservative about time spent waiting for the response.
      started = ExchangeClock.new(@clock.now)
      @client.refresh(refresh_token).grant(previous, lease.credential.query.grant.kind, started)
    rescue error : ResponseError
      rejected = error.code.reauthorization_required? &&
                 {"invalid_refresh_token", "invalid_grant", "token_revoked"}.includes?(error.slack_error) &&
                 ((200..299).includes?(error.http_status) || {400, 401, 403}.includes?(error.http_status))
      @store.fail_refresh(lease, rejected ? RefreshFailure::Rejected : RefreshFailure::UnknownRemoteOutcome)
      raise ContractError.new(rejected ? ErrorCode::ReauthorizationRequired : ErrorCode::UnknownRemoteOutcome,
        error.http_status, error.retry_after)
    rescue error : ContractError
      # Dispatched cannot be released, even when the transport proves no bytes left.
      @store.fail_refresh(lease, RefreshFailure::UnknownRemoteOutcome)
      raise ContractError.new(error.code.transport_failure? ? ErrorCode::TransportFailure : ErrorCode::UnknownRemoteOutcome)
    end

    private def persist(pending : PendingRotation) : CredentialReference
      record = @store.complete_refresh(pending.lease, pending.replacement)
      query = pending.lease.credential.query
      stored = record.grant(query.grant) || raise ContractError.new(:missing_grant)
      CredentialReference.new(query, record.version.generation, stored.revision)
    rescue error : ContractError
      raise RotationPersistenceError.new(pending) if error.code.persistence_failure?
      raise error
    end

    private class ExchangeClock < Clock
      getter now : Time

      def initialize(@now : Time)
      end
    end
  end
end
