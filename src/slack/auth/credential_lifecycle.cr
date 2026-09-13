require "./prepared_lifecycle_delivery"

module Slack::Auth
  enum LifecycleOutcome
    Applied
    AlreadyAbsent
    Superseded
  end

  # Credential-free cleanup. No fibers or network calls are started by this service.
  class CredentialLifecycle
    def initialize(@expected_app_id : String, @store : InstallationStore,
                   @clock : Proc(Time) = -> { Time.utc })
      raise ContractError.new(:invalid_configuration) if @expected_app_id.empty?
    end

    def prepare(request : HTTP::Request, selected_owner : InstallationKey? = nil) : PreparedLifecycleDelivery
      PreparedLifecycleDelivery.new(request, @expected_app_id, @store, selected_owner, @clock)
    end

    def process(request : HTTP::Request, selected_owner : InstallationKey? = nil) : LifecycleOutcome
      apply(prepare(request, selected_owner))
    end

    # Retry the same prepared object. Do not prepare an old event against new grants.
    def apply(delivery : PreparedLifecycleDelivery) : LifecycleOutcome
      unless delivery.owner.app_id == @expected_app_id
        raise RequestAuthorizationError.new(:app_mismatch)
      end
      raise RequestAuthorizationError.new(:store_mismatch) unless delivery.prepared_for?(@store)
      3.times do |attempt|
        return cleanup(delivery)
      rescue error : ContractError
        # A fresh CAS revision can only remove unchanged, originally selected grants.
        # Uninstall can adopt a revision only inside the original generation.
        raise error unless error.code.conflict? && attempt < 2
      end
      raise ContractError.new(:conflict)
    end

    private def cleanup(delivery : PreparedLifecycleDelivery) : LifecycleOutcome
      record = @store.fetch(delivery.owner)
      return LifecycleOutcome::AlreadyAbsent if record.nil? || record.deleted?
      expected = delivery.version
      return LifecycleOutcome::Superseded unless expected && record.version.generation == expected.generation

      if delivery.uninstall?
        @store.delete(delivery.owner, record.version)
        return LifecycleOutcome::Applied
      end

      targets = delivery.targets
      targets.each do |key, revision|
        if grant = record.grant(key)
          raise ContractError.new(:conflict) unless grant.revision == revision
        end
      end
      changed = false
      targets.each_key do |key|
        next unless record.grant(key)
        record = @store.invalidate(delivery.owner, key, record.version)
        changed = true
      end
      changed ? LifecycleOutcome::Applied : LifecycleOutcome::AlreadyAbsent
    end
  end
end
