require "./fakes"

# Sequential executable protocol model, NOT the reference/durable adapter owned by D.
# It intentionally makes no cross-process or thread-safety claim.
module AuthSupport
  class ProtocolStore < Slack::Auth::InstallationStore
    include Slack::Auth

    @records = {} of InstallationKey => InstallationRecord
    @ownership = {} of Tuple(InstallationKey, GrantKey) => RefreshOwnership
    @fence = 0_i64

    def initialize(@clock : Clock)
    end

    def fetch(key : InstallationKey) : InstallationRecord?
      @records[key]?
    end

    def store(key : InstallationKey, patch : InstallationPatch, expected : Version?) : InstallationRecord
      old = fetch(key)
      raise ContractError.new(:conflict) unless old.try(&.version) == expected
      generation = old ? old.version.generation + (old.deleted? ? 1 : 0) : 1_i64
      revision = (old.try(&.version.revision) || 0_i64) + 1
      previous = old unless old.try(&.deleted?)
      users = previous.try(&.users) || {} of String => StoredGrant
      bot = previous.try(&.bot)
      if grant = patch.bot
        bot = StoredGrant.new(grant, revision)
        @ownership.delete({key, GrantKey.new(:bot)})
      end
      patch.users.each do |id, user_grant|
        users[id] = StoredGrant.new(user_grant, revision)
        @ownership.delete({key, GrantKey.new(:user, id)})
      end
      @records[key] = InstallationRecord.new(key, Version.new(generation, revision), bot, users,
        patch.webhook || previous.try(&.webhook))
    end

    def delete(key : InstallationKey, expected : Version) : InstallationRecord
      current(key, expected)
      @ownership.reject! { |pair, _| pair[0] == key }
      @records[key] = InstallationRecord.new(key,
        Version.new(expected.generation + 1, expected.revision + 1), deleted: true)
    end

    def invalidate(key : InstallationKey, grant : GrantKey, expected : Version) : InstallationRecord
      old = current(key, expected)
      users = old.users
      bot = old.bot
      if grant.kind.bot?
        bot = nil
      else
        users.delete(grant.user_id)
      end
      @ownership.delete({key, grant})
      @records[key] = InstallationRecord.new(key,
        Version.new(expected.generation, expected.revision + 1), bot, users, old.webhook)
    end

    def acquire(query : InstallationQuery) : CredentialReference
      record = active(query.owner)
      grant = record.grant(query.grant) || raise ContractError.new(:missing_grant)
      CredentialReference.new(query, record.version.generation, grant.revision)
    end

    def credential_for_dispatch(reference : CredentialReference) : Secret
      grant = checked(reference)
      status = refresh_status(reference.query)
      raise ContractError.new(:unknown_remote_outcome) if status.try(&.phase.uncertain?)
      raise ContractError.new(:refresh_busy) if status.try(&.phase.dispatched?)
      raise ContractError.new(:reauthorization_required) if grant.expires_at.try { |expiry| expiry <= @clock.now }
      grant.access_token
    end

    def claim_refresh(reference : CredentialReference, lease_duration : Time::Span) : RefreshLease
      grant = checked(reference)
      raise ContractError.new(:invalid_configuration) unless lease_duration > Time::Span.zero
      raise ContractError.new(:reauthorization_required) unless grant.refresh_token
      if status = refresh_status(reference.query)
        raise ContractError.new(status.phase.uncertain? ? ErrorCode::UnknownRemoteOutcome : ErrorCode::RefreshBusy)
      end
      @fence += 1
      lease = RefreshLease.new(reference, @fence, @clock.now + lease_duration)
      @ownership[pair(reference)] = RefreshOwnership.new(lease, :acquired)
      lease
    end

    def refresh_status(query : InstallationQuery) : RefreshOwnership?
      key = {query.owner, query.grant}
      if status = @ownership[key]?
        if status.lease.expires_at <= @clock.now
          if status.phase.acquired?
            @ownership.delete(key)
            return
          end
          status = RefreshOwnership.new(status.lease, :uncertain)
          @ownership[key] = status
        end
        status
      end
    end

    def mark_refresh_dispatched(lease : RefreshLease) : Nil
      owned(lease, :acquired)
      @ownership[pair(lease.credential)] = RefreshOwnership.new(lease, :dispatched)
    end

    def release_refresh(lease : RefreshLease) : Nil
      owned(lease, :acquired)
      @ownership.delete(pair(lease.credential))
    end

    def complete_refresh(lease : RefreshLease, replacement : Grant) : InstallationRecord
      owned(lease, :dispatched)
      reference = lease.credential
      previous = checked(reference)
      raise ContractError.new(:invalid_identity) unless previous.subject_id == replacement.subject_id
      query = reference.query
      patch = query.grant.kind.bot? ? InstallationPatch.new(bot: replacement) : InstallationPatch.new(users: {(query.grant.user_id || raise ContractError.new(:invalid_identity)) => replacement})
      store(query.owner, patch, active(query.owner).version)
    end

    def fail_refresh(lease : RefreshLease, failure : RefreshFailure) : Nil
      owned(lease, :dispatched)
      if failure.rejected?
        query = lease.credential.query
        invalidate(query.owner, query.grant, active(query.owner).version)
      else
        @ownership[pair(lease.credential)] = RefreshOwnership.new(lease, :uncertain)
      end
    end

    private def pair(reference : CredentialReference)
      {reference.query.owner, reference.query.grant}
    end

    private def active(key : InstallationKey) : InstallationRecord
      record = fetch(key)
      raise ContractError.new(:missing_installation) if !record || record.deleted?
      record
    end

    private def current(key : InstallationKey, expected : Version) : InstallationRecord
      record = active(key)
      raise ContractError.new(:conflict) unless record.version == expected
      record
    end

    private def checked(reference : CredentialReference) : Grant
      record = active(reference.query.owner)
      grant = record.grant(reference.query.grant)
      unless grant && record.version.generation == reference.generation && grant.revision == reference.grant_revision
        raise ContractError.new(:conflict)
      end
      grant.grant
    end

    private def owned(lease : RefreshLease, phase : RefreshPhase) : Nil
      checked(lease.credential)
      status = refresh_status(lease.credential.query)
      unless status && status.lease == lease && status.phase == phase && lease.expires_at > @clock.now
        raise ContractError.new(:conflict)
      end
    end
  end
end
