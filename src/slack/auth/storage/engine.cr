require "../contracts"

# Internal transaction state. Access only through an adapter transaction.
module Slack::Auth::Storage
  class Engine < Slack::Auth::InstallationStore
    include Slack::Auth

    @records = {} of InstallationKey => InstallationRecord
    @ownership = {} of Tuple(InstallationKey, GrantKey) => RefreshOwnership

    getter records : Hash(InstallationKey, InstallationRecord)
    getter ownership : Hash(Tuple(InstallationKey, GrantKey), RefreshOwnership)
    getter fence : Int64

    def initialize(@clock : Clock, records : Array(InstallationRecord) = [] of InstallationRecord,
                   ownership : Array(RefreshOwnership) = [] of RefreshOwnership, @fence : Int64 = 0_i64)
      records.each { |record| @records[record.key] = record }
      ownership.each { |owner| @ownership[pair(owner.lease.credential)] = owner }
    end

    def fetch(key : InstallationKey) : InstallationRecord?
      @records[key]?
    end

    def store(key : InstallationKey, patch : InstallationPatch, expected : Version?) : InstallationRecord
      old = fetch(key)
      raise ContractError.new(:conflict) unless old.try(&.version) == expected
      generation = old.try(&.version.generation) || 1_i64
      generation = increment(generation) if old.try(&.deleted?)
      revision = increment(old.try(&.version.revision) || 0_i64)
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
      version = Version.new(increment(expected.generation), increment(expected.revision))
      @ownership.reject! { |pair, _| pair[0] == key }
      @records[key] = InstallationRecord.new(key, version, deleted: true)
    end

    def invalidate(key : InstallationKey, grant : GrantKey, expected : Version) : InstallationRecord
      old = current(key, expected)
      raise ContractError.new(:missing_grant) unless old.grant(grant)
      revision = increment(expected.revision)
      users = old.users
      bot = old.bot
      if grant.kind.bot?
        bot = nil
      else
        users.delete(grant.user_id)
      end
      @ownership.delete({key, grant})
      @records[key] = InstallationRecord.new(key,
        Version.new(expected.generation, revision), bot, users, old.webhook)
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
      @fence = increment(@fence)
      lease = RefreshLease.new(reference, @fence, @clock.now + lease_duration)
      @ownership[pair(reference)] = RefreshOwnership.new(lease, :acquired)
      lease
    end

    def refresh_status(query : InstallationQuery) : RefreshOwnership?
      key = {query.owner, query.grant}
      status = @ownership[key]?
      return status unless status && status.lease.expires_at <= @clock.now

      if status.phase.acquired?
        @ownership.delete(key)
        return
      end
      @ownership[key] = RefreshOwnership.new(status.lease, :uncertain)
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
      previous = owned(lease, :dispatched)
      raise ContractError.new(:invalid_identity) unless previous.subject_id == replacement.subject_id
      query = lease.credential.query
      patch = if query.grant.kind.bot?
                InstallationPatch.new(bot: replacement)
              else
                user_id = query.grant.user_id || raise ContractError.new(:invalid_identity)
                InstallationPatch.new(users: {user_id => replacement})
              end
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

    private def pair(reference : CredentialReference) : Tuple(InstallationKey, GrantKey)
      {reference.query.owner, reference.query.grant}
    end

    private def increment(value : Int64) : Int64
      raise ContractError.new(:persistence_failure) if value == Int64::MAX
      value + 1
    end

    private def active(key : InstallationKey) : InstallationRecord
      record = fetch(key)
      raise ContractError.new(:missing_installation) if !record || record.deleted?
      record
    end

    private def current(key : InstallationKey, expected : Version) : InstallationRecord
      record = fetch(key) || raise ContractError.new(:missing_installation)
      raise ContractError.new(:conflict) unless record.version == expected
      raise ContractError.new(:missing_installation) if record.deleted?
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

    private def owned(lease : RefreshLease, phase : RefreshPhase) : Grant
      grant = checked(lease.credential)
      status = refresh_status(lease.credential.query)
      unless status && status.lease == lease && status.phase == phase && lease.expires_at > @clock.now
        raise ContractError.new(:conflict)
      end
      grant
    end
  end
end
