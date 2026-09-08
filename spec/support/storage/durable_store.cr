require "./snapshot"

module StorageSupport
  enum Fault
    None
    BeforeCommit
    AfterCommit
  end

  # TEST ONLY: local filesystem, cooperating processes, synthetic credentials.
  # A permanent lock inode orders read/modify/replace across processes. A mutex
  # orders fibers of this instance. Nonblocking flock yields with a bounded wait.
  # No worker fibers or channels survive a transaction.
  class DurableStore < Slack::Auth::MemoryInstallationStore
    property fault : Fault = Fault::None

    def initialize(@directory : String, clock : Slack::Auth::Clock = Slack::Auth::SystemClock.new)
      super(clock)
      Dir.mkdir_p(@directory, mode: 0o700)
    end

    protected def transaction(& : Slack::Auth::Storage::Engine -> T) : T forall T
      @mutex.synchronize do
        # Closing the file releases the process lock, including on failure.
        File.open(File.join(@directory, "lock"), "a", perm: 0o600) do |lock|
          obtain_lock(lock)
          engine = restore
          result = yield engine
          raise Slack::Auth::ContractError.new(:persistence_failure) if consume_fault(Fault::BeforeCommit)
          persist(engine)
          raise Slack::Auth::ContractError.new(:persistence_failure) if consume_fault(Fault::AfterCommit)
          result
        end
      end
    rescue error : Slack::Auth::ContractError
      raise error
    rescue
      # Raw filesystem/JSON exceptions can contain sensitive paths or content.
      raise Slack::Auth::ContractError.new(:persistence_failure)
    end

    private def consume_fault(expected : Fault) : Bool
      return false unless @fault == expected
      @fault = Fault::None
      true
    end

    private def obtain_lock(lock : File) : Nil
      deadline = Time.instant + 5.seconds
      loop do
        lock.flock_exclusive(blocking: false)
        return
      rescue IO::Error
        raise Slack::Auth::ContractError.new(:persistence_failure) if Time.instant >= deadline
        sleep 1.millisecond
      end
    end

    private def restore : Slack::Auth::Storage::Engine
      path = File.join(@directory, "snapshot.json")
      return Slack::Auth::Storage::Engine.new(@clock) unless File.exists?(path)
      snapshot = Snapshot.from_json(File.read(path))
      Slack::Auth::Storage::Engine.new(@clock, snapshot.records, snapshot.ownership, snapshot.fence)
    end

    private def persist(engine : Slack::Auth::Storage::Engine) : Nil
      temporary = File.join(@directory, "pending.json")
      File.open(temporary, "w", perm: 0o600) do |file|
        Snapshot.new(engine).to_json(file)
        file.flush
        file.fsync
      end
      File.rename(temporary, File.join(@directory, "snapshot.json"))
      File.open(@directory, &.fsync)
    end
  end
end
