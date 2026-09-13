require "../storage/durable_store"

module RotationSupport
  # Inject a single failure at a named production protocol operation.
  class FaultStore < StorageSupport::DurableStore
    property dispatch_fault : StorageSupport::Fault = StorageSupport::Fault::None
    property reconciliation_fault : StorageSupport::Fault = StorageSupport::Fault::None
    property completion_fault : StorageSupport::Fault = StorageSupport::Fault::None

    def mark_refresh_dispatched(lease : Slack::Auth::RefreshLease) : Nil
      self.fault = @dispatch_fault
      @dispatch_fault = StorageSupport::Fault::None
      super
    rescue error : Slack::Auth::ContractError
      self.fault = @reconciliation_fault
      @reconciliation_fault = StorageSupport::Fault::None
      raise error
    end

    def complete_refresh(lease : Slack::Auth::RefreshLease, replacement : Slack::Auth::Grant) : Slack::Auth::InstallationRecord
      self.fault = @completion_fault
      @completion_fault = StorageSupport::Fault::None
      super
    end
  end
end
