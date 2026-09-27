module CompileContracts
  record Result,
    fixture : String,
    status : Process::Status,
    output : String,
    elapsed : Time::Span

  TIMEOUT = 30.seconds

  def self.compile(root : String, fixture : String) : Result
    output_path = File.tempname("block-kit-compile-output")
    output = IO::Memory.new
    started_at = Time.instant
    process = Process.new(
      "crystal",
      ["build", "--no-codegen", "--error-trace", "-o", output_path, fixture],
      chdir: root,
      output: output,
      error: output
    )
    joined = false

    begin
      status = join(process, TIMEOUT)
      joined = true
      Result.new(fixture, status, output.to_s, Time.instant - started_at)
    ensure
      unless joined
        terminate(process)
      end
      File.delete?(output_path)
    end
  end

  def self.execute(
    root : String,
    fixture : String,
    env : Hash(String, String?),
  ) : Result
    output = IO::Memory.new
    started_at = Time.instant
    process = Process.new(
      "crystal",
      ["run", fixture],
      chdir: root,
      env: env,
      output: output,
      error: output
    )
    joined = false

    begin
      status = join(process, TIMEOUT)
      joined = true
      Result.new(fixture, status, output.to_s, Time.instant - started_at)
    ensure
      terminate(process) unless joined
    end
  end

  def self.assert_pass(result : Result) : Nil
    raise "compiler crashed for #{result.fixture}:\n#{result.output}" if compiler_crash?(result)
    return if result.status.success?

    raise "expected #{result.fixture} to compile:\n#{result.output}"
  end

  def self.assert_fail(result : Result, diagnostic : String) : Nil
    raise "compiler crashed for #{result.fixture}:\n#{result.output}" if compiler_crash?(result)
    raise "expected #{result.fixture} to fail compilation" if result.status.success?
    if dependency_failure?(result.output)
      raise "dependency failure is not a compile contract:\n#{result.output}"
    end
    return if result.output.includes?(diagnostic)

    raise "expected diagnostic #{diagnostic.inspect} for #{result.fixture}:\n#{result.output}"
  end

  private def self.join(process : Process, timeout : Time::Span) : Process::Status
    deadline = Time.instant + timeout
    until process.terminated?
      if Time.instant >= deadline
        raise "compiler timed out after #{timeout.total_seconds.to_i} seconds"
      end
      sleep 1.millisecond
    end
    process.wait
  end

  private def self.terminate(process : Process) : Nil
    unless process.terminated?
      process.signal(Signal::TERM)
      deadline = Time.instant + 250.milliseconds
      until process.terminated? || Time.instant >= deadline
        sleep 1.millisecond
      end
      process.signal(Signal::KILL) unless process.terminated?
    end
    process.wait
  end

  private def self.dependency_failure?(output : String) : Bool
    output.includes?("can't find file") ||
      output.includes?("Error opening file") ||
      output.includes?("file does not exist")
  end

  private def self.compiler_crash?(result : Result) : Bool
    result.status.signal_exit? ||
      result.output.includes?("Please report a bug") ||
      result.output.includes?("Invalid memory access") ||
      result.output.includes?("Segmentation fault") ||
      result.output.includes?("Stack overflow")
  end
end
