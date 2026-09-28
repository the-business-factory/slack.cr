module SpecSupport
  # :nodoc:
  # One compiler cache directory for the whole suite, including every child
  # compile the suite starts. The compiler writes each `crystal spec` executable
  # to the same file name inside its cache directory, and the default cache is
  # shared by every checkout on the machine, so concurrent runs in different
  # checkouts overwrite each other. A directory inside the checkout keeps the
  # object cache warm between runs and isolates each checkout.
  module CrystalCache
    ROOT = File.expand_path("../..", __DIR__)

    def self.directory : String
      path = ENV["CRYSTAL_CACHE_DIR"]? || File.join(ROOT, ".crystal-cache")
      Dir.mkdir_p(path)
      path
    end

    def self.env : Hash(String, String?)
      Hash(String, String?){"CRYSTAL_CACHE_DIR" => directory}
    end
  end
end
