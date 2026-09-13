require "../spec_helper"
require "file_utils"
require "../support/rotation/helpers"
require "../support/storage/durable_store"
require "../support/storage/process_helpers"

describe "rotation across processes" do
  binary = File.tempname("rotation-probe")
  directory = ""
  clock = StorageSupport::Clock.new

  before_all do
    output = IO::Memory.new
    status = Process.run("crystal", ["build", "spec/support/rotation/process_probe.cr", "-o", binary], output: output, error: output)
    raise output.to_s unless status.success?
  end

  after_all do
    File.delete(binary) if File.exists?(binary)
    File.delete("#{binary}.dwarf") if File.exists?("#{binary}.dwarf")
  end

  before_each do
    directory = File.tempname("rotation-process")
    clock = StorageSupport::Clock.new
    store = StorageSupport::DurableStore.new(directory, clock)
    RotationSupport.seed(store, clock.now)
    File.write(File.join(directory, "clock"), clock.now.to_unix.to_s)
  end

  after_each { FileUtils.rm_rf(directory) }

  it "performs one effective refresh and reads the replacement in a restarted process" do
    StorageSupport.with_probes(binary, directory, "rotate", ["one", "two"]) do |processes|
      # The winner waits inside its offline transport until the loser has returned.
      deadline = Time.instant + 10.seconds
      until File.exists?(File.join(directory, "result-one")) || File.exists?(File.join(directory, "result-two"))
        raise "rotation contention timed out" if Time.instant >= deadline
        sleep 1.millisecond
      end
      File.write(File.join(directory, "finish"), "finish")
      processes.each { |process| StorageSupport.join(process).success?.should be_true }
      results = ["one", "two"].map { |id| File.read(File.join(directory, "result-#{id}")) }
      results.sort.should eq(["RefreshBusy", "synthetic-next-bot"])
      Dir.glob(File.join(directory, "sent-*")).size.should eq(1)
    end
    StorageSupport.with_probes(binary, directory, "read", ["restart"]) do |processes|
      StorageSupport.join(processes.first).success?.should be_true
      File.read(File.join(directory, "result-restart")).should eq("synthetic-next-bot")
    end
    restarted = StorageSupport::DurableStore.new(directory, clock)
    bot = restarted.fetch(RotationSupport.query.owner).should_not(be_nil).bot.should_not(be_nil).grant
    bot.refresh_token.should_not(be_nil).value.should eq("synthetic-next-refresh")
    bot.expires_at.should eq(clock.now + 3600.seconds)
    restarted.credential_for_dispatch(restarted.acquire(RotationSupport.query("U1"))).value.should eq("synthetic-old-U1")
  end

  it "never resends a possibly consumed token after the owner dies and restarts" do
    StorageSupport.with_probes(binary, directory, "rotate", ["crash"]) do |processes|
      StorageSupport.await_file(File.join(directory, "sent-crash"))
      processes.first.signal(Signal::KILL)
      processes.first.wait.success?.should be_false
    end
    clock.now += 2.minutes
    File.write(File.join(directory, "clock"), clock.now.to_unix.to_s)
    StorageSupport.with_probes(binary, directory, "rotate", ["restart"]) do |processes|
      StorageSupport.join(processes.first).success?.should be_true
      File.read(File.join(directory, "result-restart")).should eq("UnknownRemoteOutcome")
    end
    Dir.glob(File.join(directory, "sent-*")).size.should eq(1)
  end

  it "takes a new fence after an abandoned Acquired lease expires" do
    store = StorageSupport::DurableStore.new(directory, clock)
    lease = store.claim_refresh(store.acquire(RotationSupport.query), 2.minutes)
    clock.now = lease.expires_at
    File.write(File.join(directory, "clock"), clock.now.to_unix.to_s)
    StorageSupport.with_probes(binary, directory, "rotate", ["new-owner"]) do |processes|
      StorageSupport.await_file(File.join(directory, "sent-new-owner"))
      current = store.refresh_status(RotationSupport.query).should_not(be_nil)
      current.lease.fence.should be > lease.fence
      expect_raises(Slack::Auth::ContractError) { store.mark_refresh_dispatched(lease) }.code.should eq(Slack::Auth::ErrorCode::Conflict)
      File.write(File.join(directory, "finish"), "finish")
      StorageSupport.join(processes.first).success?.should be_true
      File.read(File.join(directory, "result-new-owner")).should eq("synthetic-next-bot")
    end
  end
end
