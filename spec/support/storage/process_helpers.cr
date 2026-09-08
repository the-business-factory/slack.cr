module StorageSupport
  def self.await_file(path : String) : Nil
    deadline = Time.instant + 10.seconds
    until File.exists?(path)
      raise "process barrier timed out" if Time.instant >= deadline
      sleep 1.millisecond
    end
  end

  def self.join(process : Process) : Process::Status
    deadline = Time.instant + 10.seconds
    until process.terminated?
      if Time.instant >= deadline
        process.signal(Signal::KILL)
        process.wait
        raise "process completion timed out"
      end
      sleep 1.millisecond
    end
    process.wait
  end

  # The caller owns these children until every result is joined or cleanup runs.
  def self.with_probes(binary : String, directory : String, action : String,
                       identities : Array(String), & : Array(Process) ->) : Nil
    processes = [] of Process
    begin
      identities.each do |identity|
        processes << Process.new(binary, [directory, action, identity],
          output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
      end
      identities.each { |identity| await_file(File.join(directory, "ready-#{identity}")) }
      identities.each { |identity| File.write(File.join(directory, "start-#{identity}"), "go") }
      yield processes
    ensure
      processes.each do |process|
        unless process.terminated?
          process.signal(Signal::KILL)
          process.wait
        end
      end
    end
  end
end
