require "../spec_helper"
require "../support/storage/conformance"
require "../support/storage/durable_store"

StorageSupport.conformance("memory installation adapter",
  ->(clock : StorageSupport::Clock, _directory : String) { Slack::Auth::MemoryInstallationStore.new(clock) })
StorageSupport.conformance("durable test installation adapter",
  ->(clock : StorageSupport::Clock, directory : String) { StorageSupport::DurableStore.new(directory, clock) })

describe Slack::Auth::Storage::Engine do
  it "rejects revision and generation overflow without discarding credentials or ownership" do
    clock = StorageSupport::Clock.new
    key = StorageSupport.key
    [Slack::Auth::Version.new(1_i64, Int64::MAX), Slack::Auth::Version.new(Int64::MAX, 1_i64)].each do |version|
      record = Slack::Auth::InstallationRecord.new(key, version, Slack::Auth::StoredGrant.new(StorageSupport.grant, 1_i64))
      engine = Slack::Auth::Storage::Engine.new(clock, [record])
      lease = engine.claim_refresh(engine.acquire(StorageSupport.query), 1.minute)
      StorageSupport.failure(:persistence_failure) { engine.delete(key, version) }
      engine.fetch(key).should_not(be_nil).version.should eq(version)
      engine.refresh_status(StorageSupport.query).should_not(be_nil).lease.should eq(lease)
      if version.revision == Int64::MAX
        StorageSupport.failure(:persistence_failure) { engine.store(key, Slack::Auth::InstallationPatch.new(bot: StorageSupport.grant), version) }
        StorageSupport.failure(:persistence_failure) { engine.invalidate(key, Slack::Auth::GrantKey.new(:bot), version) }
        engine.refresh_status(StorageSupport.query).should_not(be_nil).lease.should eq(lease)
      end
    end
  end

  it "rejects fence overflow without assigning an owner" do
    clock = StorageSupport::Clock.new
    record = Slack::Auth::InstallationRecord.new(StorageSupport.key, Slack::Auth::Version.new(1_i64, 1_i64), Slack::Auth::StoredGrant.new(StorageSupport.grant, 1_i64))
    engine = Slack::Auth::Storage::Engine.new(clock, [record], fence: Int64::MAX)
    StorageSupport.failure(:persistence_failure) { engine.claim_refresh(engine.acquire(StorageSupport.query), 1.minute) }
    engine.refresh_status(StorageSupport.query).should be_nil
  end
end
