require "../crystal_cache"

module SpecSupport
  # :nodoc:
  # Builds the shared subprocess probe once per spec run and removes it at exit.
  # The rotation and durable-storage specs start this binary as separate
  # processes; see `probe.cr` for the argument protocol.
  module ProbeBinary
    SOURCE = "spec/support/processes/probe.cr"

    @@path : String?

    def self.path : String
      @@path ||= build
    end

    private def self.build : String
      binary = File.tempname("slack-spec-probe")
      output = IO::Memory.new
      status = Process.run("crystal", ["build", SOURCE, "-o", binary],
        chdir: CrystalCache::ROOT, env: CrystalCache.env, output: output, error: output)
      raise "probe build failed:\n#{output}" unless status.success?
      at_exit do
        File.delete?(binary)
        File.delete?("#{binary}.dwarf")
      end
      binary
    end
  end
end
