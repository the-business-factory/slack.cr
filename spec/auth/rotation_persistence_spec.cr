require "../spec_helper"
require "file_utils"
require "../support/rotation/helpers"
require "../support/rotation/fault_store"

describe "durable rotation recovery" do
  directory = ""
  clock = StorageSupport::Clock.new
  store : RotationSupport::FaultStore? = nil
  transport = RotationSupport::Transport.new

  before_each do
    directory = File.tempname("rotation-recovery")
    clock = StorageSupport::Clock.new
    adapter = RotationSupport::FaultStore.new(directory, clock)
    store = adapter
    RotationSupport.seed(adapter, clock.now)
    transport = RotationSupport::Transport.new
  end

  after_each { FileUtils.rm_rf(directory) }

  it "does not send after a rolled-back dispatch write and releases only Acquired ownership" do
    adapter = store.should_not(be_nil)
    adapter.dispatch_fault = :before_commit
    service = RotationSupport.service(adapter, transport, clock)
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::PersistenceFailure)
    transport.requests.should be_empty
    adapter.refresh_status(RotationSupport.query).should be_nil
    service.rotate(RotationSupport.query)
    transport.requests.size.should eq(1)
  end

  it "reads durable Dispatched ownership after a lost acknowledgment before sending once" do
    adapter = store.should_not(be_nil)
    adapter.dispatch_fault = :after_commit
    RotationSupport.service(adapter, transport, clock).rotate(RotationSupport.query)
    transport.requests.size.should eq(1)
    restarted = StorageSupport::DurableStore.new(directory, clock)
    restarted.credential_for_dispatch(restarted.acquire(RotationSupport.query)).value.should eq("synthetic-next-bot")
  end

  it "sends nothing if it cannot read back an uncertain dispatch write" do
    adapter = store.should_not(be_nil)
    adapter.dispatch_fault = :after_commit
    adapter.reconciliation_fault = :before_commit
    service = RotationSupport.service(adapter, transport, clock)
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::PersistenceFailure)
    transport.requests.should be_empty
    clock.now += 2.minutes
    restarted = StorageSupport::DurableStore.new(directory, clock)
    expect_raises(Slack::Auth::ContractError) { RotationSupport.service(restarted, transport, clock).rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
    transport.requests.should be_empty
  end

  {StorageSupport::Fault::BeforeCommit, StorageSupport::Fault::AfterCommit}.each do |fault|
    it "recovers local completion after #{fault} with a new adapter and no HTTP" do
      adapter = store.should_not(be_nil)
      adapter.completion_fault = fault
      service = RotationSupport.service(adapter, transport, clock)
      error = expect_raises(Slack::Auth::RotationPersistenceError) { service.rotate(RotationSupport.query) }
      error.code.should eq(Slack::Auth::ErrorCode::PersistenceFailure)
      error.inspect.should_not contain("synthetic")
      error.pending.inspect.should_not contain("synthetic")
      error.pending.replacement.refresh_token.should_not(be_nil).value.should eq("synthetic-next-refresh")
      restarted = StorageSupport::DurableStore.new(directory, clock)
      recovery_transport = RotationSupport::Transport.new
      recovery = RotationSupport.service(restarted, recovery_transport, clock)
      current = recovery.recover(error.pending)
      restarted.credential_for_dispatch(current).value.should eq("synthetic-next-bot")
      recovery.recover(error.pending).should eq(current)
      recovery_transport.requests.should be_empty
      transport.requests.size.should eq(1)
    end
  end

  it "retains the pending replacement through another local failure" do
    adapter = store.should_not(be_nil)
    adapter.completion_fault = :before_commit
    service = RotationSupport.service(adapter, transport, clock)
    first = expect_raises(Slack::Auth::RotationPersistenceError) { service.rotate(RotationSupport.query) }
    adapter.completion_fault = :before_commit
    second = expect_raises(Slack::Auth::RotationPersistenceError) { service.recover(first.pending) }
    second.pending.should eq(first.pending)
    service.recover(second.pending)
    transport.requests.size.should eq(1)
  end

  it "does not accept an unrelated newer grant as its lost completion" do
    adapter = store.should_not(be_nil)
    adapter.completion_fault = :before_commit
    service = RotationSupport.service(adapter, transport, clock)
    error = expect_raises(Slack::Auth::RotationPersistenceError) { service.rotate(RotationSupport.query) }
    record = adapter.fetch(RotationSupport.query.owner).should_not(be_nil)
    adapter.store(record.key, Slack::Auth::InstallationPatch.new(bot: RotationSupport.grant("B1", clock.now + 1.hour, "other-refresh")), record.version)
    expect_raises(Slack::Auth::ContractError) { service.recover(error.pending) }.code.should eq(Slack::Auth::ErrorCode::Conflict)
    transport.requests.size.should eq(1)
  end

  it "rejects recovery in a new generation even if credentials are identical" do
    adapter = store.should_not(be_nil)
    adapter.completion_fault = :before_commit
    service = RotationSupport.service(adapter, transport, clock)
    error = expect_raises(Slack::Auth::RotationPersistenceError) { service.rotate(RotationSupport.query) }
    record = adapter.fetch(RotationSupport.query.owner).should_not(be_nil)
    tombstone = adapter.delete(record.key, record.version)
    adapter.store(record.key, Slack::Auth::InstallationPatch.new(bot: error.pending.replacement), tombstone.version)
    expect_raises(Slack::Auth::ContractError) { service.recover(error.pending) }.code.should eq(Slack::Auth::ErrorCode::Conflict)
    transport.requests.size.should eq(1)
  end

  it "rejects local completion at lease expiry and never repeats refresh HTTP" do
    adapter = store.should_not(be_nil)
    adapter.completion_fault = :before_commit
    service = RotationSupport.service(adapter, transport, clock)
    error = expect_raises(Slack::Auth::RotationPersistenceError) { service.rotate(RotationSupport.query) }
    clock.now = error.pending.lease.expires_at
    expect_raises(Slack::Auth::ContractError) { service.recover(error.pending) }.code.should eq(Slack::Auth::ErrorCode::Conflict)
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
    transport.requests.size.should eq(1)
  end

  it "keeps a failed quarantine write fenced through restart and lease expiry" do
    adapter = store.should_not(be_nil)
    transport.before_response = -> : Nil { adapter.fault = :before_commit; raise Slack::Auth::ContractError.new(:unknown_remote_outcome) }
    service = RotationSupport.service(adapter, transport, clock)
    expect_raises(Slack::Auth::ContractError) { service.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::PersistenceFailure)
    restarted = StorageSupport::DurableStore.new(directory, clock)
    recovered = RotationSupport.service(restarted, transport, clock)
    expect_raises(Slack::Auth::ContractError) { recovered.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::RefreshBusy)
    clock.now += 2.minutes
    expect_raises(Slack::Auth::ContractError) { recovered.rotate(RotationSupport.query) }.code.should eq(Slack::Auth::ErrorCode::UnknownRemoteOutcome)
    transport.requests.size.should eq(1)
  end
end
