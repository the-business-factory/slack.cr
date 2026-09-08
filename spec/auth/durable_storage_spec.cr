require "../spec_helper"
require "../support/storage/conformance"
require "../support/storage/durable_store"
require "../support/storage/process_helpers"

describe StorageSupport::DurableStore do
  directory = ""
  clock = StorageSupport::Clock.new
  binary = File.tempname("storage-probe")
  unused_directory = File.tempname("unused-storage")
  store = StorageSupport::DurableStore.new(unused_directory)

  before_all do
    owned_cache : String? = nil
    cache = ENV["CRYSTAL_CACHE_DIR"]?
    unless cache
      cache = File.tempname("storage-probe-cache")
      Dir.mkdir(cache, 0o700)
      owned_cache = cache
    end

    begin
      output = IO::Memory.new
      status = Process.run("crystal", ["build", "spec/support/storage/process_probe.cr", "-o", binary],
        env: {"CRYSTAL_CACHE_DIR" => cache}, output: output, error: output)
      raise output.to_s unless status.success?
    ensure
      # The cache is needed only during compilation. Never remove a caller's cache.
      owned_cache.try { |path| FileUtils.rm_rf(path) }
    end
  end

  after_all do
    FileUtils.rm_rf(unused_directory)
    File.delete(binary) if File.exists?(binary)
    File.delete("#{binary}.dwarf") if File.exists?("#{binary}.dwarf")
  end

  before_each do
    directory = File.tempname("durable-storage")
    clock = StorageSupport::Clock.new
    store = StorageSupport::DurableStore.new(directory, clock)
    File.write(File.join(directory, "clock"), clock.now.to_unix.to_s)
    StorageSupport.seed(store)
  end

  after_each do
    FileUtils.rm_rf(directory)
  end

  it "restores credentials, refresh ownership and tombstones in fresh instances" do
    lease = store.claim_refresh(store.acquire(StorageSupport.query), 1.minute)
    store.mark_refresh_dispatched(lease)
    restarted = StorageSupport::DurableStore.new(directory, clock)
    restarted.refresh_status(StorageSupport.query).should_not(be_nil).lease.should eq(lease)
    completed = restarted.complete_refresh(lease, StorageSupport.grant("B1", "persisted"))
    again = StorageSupport::DurableStore.new(directory, clock)
    again.credential_for_dispatch(again.acquire(StorageSupport.query)).value.should eq("persisted")
    StorageSupport.with_probes(binary, directory, "read", ["restart"]) do |processes|
      StorageSupport.join(processes.first).success?.should be_true
      File.read(File.join(directory, "result-restart")).should eq("persisted")
    end
    tombstone = again.delete(StorageSupport.key, completed.version)
    StorageSupport::DurableStore.new(directory, clock).fetch(StorageSupport.key).should_not(be_nil).version.should eq(tombstone.version)
  end

  it "keeps previous state on failed persistence and reconciles lost dispatch acknowledgments" do
    lease = store.claim_refresh(store.acquire(StorageSupport.query), 1.minute)
    store.fault = :before_commit
    StorageSupport.failure(:persistence_failure) { store.mark_refresh_dispatched(lease) }
    store.refresh_status(StorageSupport.query).should_not(be_nil).phase.acquired?.should be_true
    store.fault = :after_commit
    StorageSupport.failure(:persistence_failure) { store.mark_refresh_dispatched(lease) }
    store.refresh_status(StorageSupport.query).should_not(be_nil).phase.dispatched?.should be_true
    StorageSupport.failure(:conflict) { store.mark_refresh_dispatched(lease) }
  end

  it "retries only local completion after rollback and detects a lost completion result" do
    lease = store.claim_refresh(store.acquire(StorageSupport.query), 1.minute)
    store.mark_refresh_dispatched(lease)
    before = store.fetch(StorageSupport.key).should_not(be_nil)
    store.fault = :before_commit
    StorageSupport.failure(:persistence_failure) { store.complete_refresh(lease, StorageSupport.grant("B1", "new")) }
    store.fetch(StorageSupport.key).should_not(be_nil).version.should eq(before.version)
    store.refresh_status(StorageSupport.query).should_not(be_nil).phase.dispatched?.should be_true
    store.fault = :after_commit
    StorageSupport.failure(:persistence_failure) { store.complete_refresh(lease, StorageSupport.grant("B1", "new")) }
    restored = StorageSupport::DurableStore.new(directory, clock)
    restored.fetch(StorageSupport.key).should_not(be_nil).bot.should_not(be_nil).revision.should be > lease.credential.grant_revision
    restored.refresh_status(StorageSupport.query).should be_nil
    restored.credential_for_dispatch(restored.acquire(StorageSupport.query)).value.should eq("new")
    StorageSupport.failure(:conflict) { restored.complete_refresh(lease, StorageSupport.grant) }
  end

  it "admits exactly one owner across two simultaneously released processes" do
    StorageSupport.with_probes(binary, directory, "claim", ["one", "two"]) do |processes|
      processes.each { |process| StorageSupport.join(process).success?.should be_true }
      results = ["one", "two"].map { |identity| File.read(File.join(directory, "result-#{identity}")) }
      results.sort.should eq(["RefreshBusy", "acquired"])
    end
  end

  it "commits exactly one competing CAS update and preserves unrelated grants across processes" do
    before = store.fetch(StorageSupport.key).should_not(be_nil)
    user = store.acquire(StorageSupport.query("U1"))
    bot = store.acquire(StorageSupport.query)
    other_user = store.acquire(StorageSupport.query("U2"))
    store.credential_for_dispatch(user).value.should eq("user1-access")
    store.credential_for_dispatch(bot).value.should eq("bot-access")
    store.credential_for_dispatch(other_user).value.should eq("user2-access")
    File.write(File.join(directory, "expected.json"), before.version.to_json)
    identities = ["store-one", "store-two"]
    StorageSupport.with_probes(binary, directory, "mutate", identities) do |processes|
      processes.each { |process| StorageSupport.join(process).success?.should be_true }
      results = identities.map { |identity| File.read(File.join(directory, "result-#{identity}")) }
      results.count("Conflict").should eq(1)
      winner = results.find { |result| result != "Conflict" }.should_not(be_nil)
      identities.should contain(winner)
      restarted = StorageSupport::DurableStore.new(directory, clock)
      current = restarted.fetch(StorageSupport.key).should_not(be_nil)
      current.version.should eq(Slack::Auth::Version.new(before.version.generation, before.version.revision + 1))
      current.bot.should eq(before.bot)
      current.users["U2"].should eq(before.users["U2"])
      current.webhook.should eq(before.webhook)
      restarted.credential_for_dispatch(restarted.acquire(StorageSupport.query("U1"))).value.should eq(winner)
      restarted.credential_for_dispatch(bot).value.should eq("bot-access")
      restarted.credential_for_dispatch(other_user).value.should eq("user2-access")
      StorageSupport.failure(:conflict) { restarted.credential_for_dispatch(user) }
    end
  end

  ["invalidate", "delete"].each do |revocation|
    it "linearizes refresh completion against #{revocation} across processes" do
      before = store.fetch(StorageSupport.key).should_not(be_nil)
      user = store.acquire(StorageSupport.query("U1"))
      bot = store.acquire(StorageSupport.query)
      other_user = store.acquire(StorageSupport.query("U2"))
      other_key = StorageSupport.key("T2")
      other = store.store(other_key, Slack::Auth::InstallationPatch.new(bot: StorageSupport.grant("B2", "other-tenant")), nil)
      other_query = Slack::Auth::InstallationQuery.new(other_key, Slack::Auth::GrantKey.new(:bot))
      store.credential_for_dispatch(user).value.should eq("user1-access")
      store.credential_for_dispatch(bot).value.should eq("bot-access")
      store.credential_for_dispatch(other_user).value.should eq("user2-access")
      lease = store.claim_refresh(user, 1.minute)
      store.mark_refresh_dispatched(lease)
      File.write(File.join(directory, "expected.json"), before.version.to_json)
      File.write(File.join(directory, "completion.json"), lease.to_json)
      StorageSupport.with_probes(binary, directory, "mutate", ["complete", revocation]) do |processes|
        processes.each { |process| StorageSupport.join(process).success?.should be_true }
        completion_result = File.read(File.join(directory, "result-complete"))
        revocation_result = File.read(File.join(directory, "result-#{revocation}"))
        restarted = StorageSupport::DurableStore.new(directory, clock)
        current = restarted.fetch(StorageSupport.key).should_not(be_nil)
        current.version.revision.should eq(before.version.revision + 1)
        restarted.refresh_status(StorageSupport.query("U1")).should be_nil
        restarted.fetch(other_key).should eq(other)
        restarted.credential_for_dispatch(restarted.acquire(other_query)).value.should eq("other-tenant")

        if revocation_result == "delete"
          completion_result.should eq("MissingInstallation")
          current.deleted?.should be_true
          current.version.generation.should eq(before.version.generation + 1)
          current.bot.should be_nil
          current.users.should be_empty
          current.webhook.should be_nil
          [user, bot, other_user].each do |reference|
            StorageSupport.failure(:missing_installation) { restarted.credential_for_dispatch(reference) }
          end
          StorageSupport.failure(:missing_installation) { restarted.complete_refresh(lease, StorageSupport.grant("U1")) }
        else
          current.deleted?.should be_false
          current.version.generation.should eq(before.version.generation)
          current.bot.should eq(before.bot)
          current.users["U2"].should eq(before.users["U2"])
          current.webhook.should eq(before.webhook)
          restarted.credential_for_dispatch(bot).value.should eq("bot-access")
          restarted.credential_for_dispatch(other_user).value.should eq("user2-access")
          StorageSupport.failure(:conflict) { restarted.credential_for_dispatch(user) }
          StorageSupport.failure(:conflict) { restarted.complete_refresh(lease, StorageSupport.grant("U1")) }
          if revocation_result == "invalidate"
            completion_result.should eq("Conflict")
            current.users.has_key?("U1").should be_false
            StorageSupport.failure(:missing_grant) { restarted.acquire(StorageSupport.query("U1")) }
          else
            revocation_result.should eq("Conflict")
            completion_result.should eq("complete")
            current.users["U1"].grant.refresh_token.should_not(be_nil).value.should eq("process-refresh")
            restarted.credential_for_dispatch(restarted.acquire(StorageSupport.query("U1"))).value.should eq("process-rotated")
          end
        end
      end
    end
  end

  ["acquired", "dispatched"].each do |phase|
    it "recovers conservatively after killing a process with #{phase} ownership" do
      StorageSupport.with_probes(binary, directory, phase, ["crash"]) do |processes|
        process = processes.first
        StorageSupport.await_file(File.join(directory, "result-crash"))
        File.read(File.join(directory, "result-crash")).should eq("acquired")
        lease = Slack::Auth::RefreshLease.from_json(File.read(File.join(directory, "lease-crash")))
        process.signal(Signal::KILL)
        StorageSupport.join(process).success?.should be_false
        clock.now += 10.seconds
        File.write(File.join(directory, "clock"), clock.now.to_unix.to_s)
        restarted = StorageSupport::DurableStore.new(directory, clock)
        if phase == "acquired"
          replacement = restarted.claim_refresh(lease.credential, 1.minute)
          replacement.fence.should be > lease.fence
        else
          restarted.refresh_status(StorageSupport.query).should_not(be_nil).phase.uncertain?.should be_true
          StorageSupport.failure(:unknown_remote_outcome) { restarted.claim_refresh(lease.credential, 1.minute) }
          StorageSupport.failure(:unknown_remote_outcome) { restarted.credential_for_dispatch(lease.credential) }
        end
        StorageSupport.failure(:conflict) { restarted.complete_refresh(lease, StorageSupport.grant) }
      end
    end
  end
end
